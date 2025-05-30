import { modules as moduleList } from "../ignition/modules";
import fs from "fs";
import { ethers } from "ethers";
import hre from "hardhat";
import { getSelector } from "../ignition/SatelliteDeployment";
import { ConsoleMenu } from "./console-menu";
import { $ } from "bun";
import { getDeployedSatellites } from "./satelliteDeploymentsManager";

const ACTION = {
  Add: 0,
  Replace: 1,
  Remove: 2,
} as const;

function getNetworkName(chainId: string) {
  const chainConfigs = Object.entries(hre.config.networks).filter(
    ([_, chainData]) => chainData.chainId == parseInt(chainId),
  );
  if (chainConfigs.length == 0) {
    console.error(`Chain ${chainId} not found in hardhat config`);
    process.exit(1);
  }
  if (chainConfigs.length > 1) {
    console.error(`Multiple chains found for ${chainId} in hardhat config`);
    process.exit(1);
  }
  return chainConfigs[0][0];
}

async function getCompiledModules(chainId: string) {
  let moduleNames: string[];
  try {
    const deploymentFile = await import("../ignition/modules/" + chainId);
    moduleNames = deploymentFile.modules;
  } catch (e) {
    console.error(
      `No module definition found for ${chainId} (ignition/modules/${chainId}.ts)`,
    );
    process.exit(1);
  }

  const modulesList = moduleList(chainId as any) as any; // TODO: fix type
  const compiledModules = moduleNames.map((name) => {
    const interfaceName = modulesList[name].interfaceName;
    const bytecode = hre.artifacts.readArtifactSync(name).deployedBytecode;
    const bytecodeHash = ethers.solidityPackedKeccak256(
      ["bytes"],
      [ethers.getBytes(bytecode)],
    );

    return {
      name,
      functionSelectors: getSelector(interfaceName),
      bytecodeHash,
      bytecode,
    };
  });

  const maintenanceModuleBytecode = await hre.artifacts.readArtifactSync(
    "SatelliteMaintenanceModule",
  );
  compiledModules.push({
    name: "SatelliteMaintenanceModule",
    functionSelectors: getSelector("SatelliteMaintenanceModule"),
    bytecodeHash: ethers.solidityPackedKeccak256(
      ["bytes"],
      [ethers.getBytes(maintenanceModuleBytecode.deployedBytecode)],
    ),
    bytecode: maintenanceModuleBytecode.deployedBytecode,
  });

  return compiledModules;
}

async function getDeployedModules(chainId: string) {
  const networkName = Object.keys(hre.config.networks).find(
    (key) => hre.config.networks[key].chainId === parseInt(chainId),
  );
  if (!networkName) {
    console.error(`No network found for chainId ${chainId}`);
    process.exit(1);
  }

  const provider = new ethers.JsonRpcProvider(
    hre.config.networks[networkName].url,
  );
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY as string, provider);

  const deployedSatellites = await getDeployedSatellites();

  const deployedAddress = deployedSatellites.satellites.find(
    (x) => x.chainId == chainId,
  )?.contractAddress;

  if (!deployedAddress) {
    console.error(`No deployed address found for chainId ${chainId}`);
    process.exit(1);
  }

  console.log("Deployed satellite is:", deployedAddress);

  const contract = await hre.ethers.getContractAt(
    "ISatellite",
    deployedAddress,
    wallet,
  );

  const deployedFacets = await contract.facets();

  const API_KEY =
    hre.config.etherscan.apiKey[
      networkName as keyof typeof hre.config.etherscan.apiKey
    ];
  if (!API_KEY) {
    console.error(`No API key found for network ${networkName}`);
    process.exit(1);
  }

  const etherscanApi = hre.config.etherscan.customChains.find(
    (x) => x.chainId == parseInt(chainId),
  )?.urls.apiURL;
  if (!etherscanApi) {
    console.error(`No etherscan API URL found for network ${networkName}`);
    process.exit(1);
  }

  console.log("Found deployed contracts:");
  const deployedModules = [];
  for (const [address, selectors] of deployedFacets) {
    // Etherscan rate limit is 5 requests per second
    await new Promise((resolve) => setTimeout(resolve, 300));
    const response = await fetch(
      `${etherscanApi}?module=contract&action=getsourcecode&address=${address}&apikey=${API_KEY}`,
    );
    const data = await response.json();

    if (data.status !== "1" || !data.result[0]) {
      console.error(`Could not fetch contract name for address ${address}`);
      process.exit(1);
    }
    const name = data.result[0].ContractName;
    const bytecode = await provider.getCode(address);
    const bytecodeHash = ethers.solidityPackedKeccak256(
      ["bytes"],
      [ethers.getBytes(bytecode)],
    );
    console.log(`${address} -> ${name}`);
    deployedModules.push({
      name,
      address,
      functionSelectors: selectors,
      bytecodeHash,
      bytecode,
    });
  }

  return [deployedModules, contract] as const;
}

interface DeployedModule {
  name: string;
  address: string;
  functionSelectors: string[];
  bytecodeHash: string;
  bytecode: string;
}

interface CompiledModule {
  name: string;
  functionSelectors: string[];
  bytecodeHash: string;
  bytecode: string;
}

async function compareModules(
  deployedModules: DeployedModule[],
  compiledModules: CompiledModule[],
) {
  const deployedMapping = new Map<string, DeployedModule>();
  for (const module of deployedModules) {
    deployedMapping.set(module.name, module);
  }

  const compiledMapping = new Map<string, CompiledModule>();
  for (const module of compiledModules) {
    compiledMapping.set(module.name, module);
  }

  const allModules = new Set([
    ...deployedMapping.keys(),
    ...compiledMapping.keys(),
  ]);

  const addedModules = [];
  const deletedModules = [];
  const updatedModules = [];
  const preservedModules = [];
  const mustUpdateModules = new Set<string>();

  for (const moduleName of allModules) {
    const deployedModule = deployedMapping.get(moduleName);
    const compiledModule = compiledMapping.get(moduleName);

    if (!deployedModule) {
      addedModules.push(compiledModule);
    } else if (!compiledModule) {
      deletedModules.push(deployedModule);
    } else if (deployedModule.bytecodeHash !== compiledModule.bytecodeHash) {
      updatedModules.push(compiledModule);
      const selectorsMatch = deployedModule.functionSelectors.every(
        (selector) => compiledModule.functionSelectors.includes(selector),
      );
      if (selectorsMatch) {
        mustUpdateModules.add(compiledModule.name);
      }
    } else {
      preservedModules.push(compiledModule);
    }
  }

  const menu = new ConsoleMenu([
    {
      label: addedModules.length ? "Added modules:" : "No added modules",
      switchable: null,
    },
    ...addedModules.map((x) => ({
      label: x!.name,
      switchable: true,
      selected: true,
    })),

    { label: "", switchable: null },

    {
      label: deletedModules.length ? "Deleted modules:" : "No deleted modules",
      switchable: null,
    },
    ...deletedModules.map((x) => ({
      label: x.name,
      switchable: true,
      selected: true,
    })),

    { label: "", switchable: null },

    {
      label:
        updatedModules.length + preservedModules.length > 0
          ? "Updated/Preserved modules: (selected - update, unselected - preserve)"
          : "No updated/preserved modules",
      switchable: null,
    },
    ...updatedModules.map((x) => ({
      label: x.name,
      switchable: mustUpdateModules.has(x.name),
      selected: true,
    })),
    ...preservedModules.map((x) => ({
      label: x.name,
      switchable: false,
      selected: false,
    })),
  ]);
  const selectedModulesResult = await menu.show();
  const selectedModules = new Set(
    selectedModulesResult
      .filter((x) => x.switchable !== null && x.selected)
      .map((x) => x.label),
  );

  const selectorToDeployedModule = new Map<string, string>();
  for (const module of deployedModules) {
    for (const selector of module.functionSelectors) {
      selectorToDeployedModule.set(selector, module.name);
    }
  }

  const selectorToCompiledModule = new Map<string, string>();
  for (const module of compiledModules) {
    for (const selector of module.functionSelectors) {
      selectorToCompiledModule.set(selector, module.name);
    }
  }

  const allSelectors = new Set([
    ...selectorToDeployedModule.keys(),
    ...selectorToCompiledModule.keys(),
  ]);

  const addedSelectors = new Map<string, string[]>();
  const deletedSelectors = new Map<string, string[]>();
  const movedSelectors: [string, string, string][] = [];
  const updatedModuleSelectors = new Map<string, string[]>();
  function append(map: Map<string, string[]>, key: string, value: string) {
    if (!map.has(key)) {
      map.set(key, []);
    }
    map.get(key)!.push(value);
  }
  for (const selector of allSelectors) {
    const deployedContract = selectorToDeployedModule.get(selector);
    const compiledContract = selectorToCompiledModule.get(selector);

    if (!deployedContract) {
      append(addedSelectors, compiledContract!, selector);
    } else if (!compiledContract) {
      append(deletedSelectors, deployedContract, selector);
    } else if (deployedContract === compiledContract) {
      if (preservedModules.find((x) => x.name === deployedContract)) continue;

      if (selectedModules.has(deployedContract)) {
        append(updatedModuleSelectors, deployedContract, selector);
      }
    } else {
      movedSelectors.push([selector, deployedContract, compiledContract]);
    }
  }
  console.log("\n========================================");
  console.log(
    addedSelectors.size
      ? "\nSelectors to be added:"
      : "\nNo selectors to be added",
  );
  for (const [module, selectors] of addedSelectors) {
    console.log("-", module + ":", selectors.join(", "));
  }
  console.log(
    deletedSelectors.size
      ? "\nSelectors to be deleted:"
      : "\nNo selectors to be deleted",
  );
  for (const [module, selectors] of deletedSelectors) {
    console.log("-", module + ":", selectors.join(", "));
  }
  console.log(
    movedSelectors.length
      ? "\nSelectors to be moved:"
      : "\nNo selectors to be moved",
  );
  for (const [selector, deployedContract, compiledContract] of movedSelectors) {
    console.log("-", selector + ":", deployedContract, "->", compiledContract);
  }
  console.log(
    updatedModuleSelectors.size
      ? "\nSelectors to be updated:"
      : "\nNo selectors to be updated",
  );
  for (const [module, selectors] of updatedModuleSelectors) {
    console.log("-", module + ":", selectors.join(", "));
  }

  const updatedModulesToDeploy = updatedModules.filter((module) =>
    selectedModules.has(module.name),
  );

  console.log("\n========================================\n");

  const confirm = prompt("Confirm that this is correct [y/N]:");
  if (confirm !== "y") {
    console.log("Aborting...");
    process.exit(0);
  }

  console.log("\n========================================\n");

  return {
    addedModules,
    deletedModules,
    updatedModules: updatedModulesToDeploy,
    preservedModules,
    addedSelectors,
    deletedSelectors,
    movedSelectors,
    updatedModuleSelectors,
  };
}

async function getMaintenanceActions(
  result: Awaited<ReturnType<typeof compareModules>>,
) {
  const modulesToDeploy = result.addedModules
    .concat(result.updatedModules)
    .map((x) => x!.name);
  // TODO: deploy those module and get their addresses

  console.log("Those modules will be deployed:");
  for (const module of modulesToDeploy) {
    console.log("-", module);
  }

  const f = function (addresses: Record<string, string>) {
    const maintenances = [];
    for (const [_module, selectors] of result.deletedSelectors) {
      maintenances.push({
        moduleAddress: addresses[_module], // TODO: 0x0 when SatelliteMaintenanceModule is fixed
        action: ACTION.Remove,
        functionSelectors: selectors,
      });
    }
    for (const [_from, to, selectors] of result.movedSelectors) {
      maintenances.push({
        moduleAddress: addresses[to],
        action: ACTION.Replace,
        functionSelectors: selectors,
      });
    }
    for (const [module, selectors] of result.updatedModuleSelectors) {
      maintenances.push({
        moduleAddress: addresses[module],
        action: ACTION.Replace,
        functionSelectors: selectors,
      });
    }
    for (const [module, selectors] of result.addedSelectors) {
      maintenances.push({
        moduleAddress: addresses[module],
        action: ACTION.Add,
        functionSelectors: selectors,
      });
    }
    return maintenances;
  };

  return [f, modulesToDeploy] as const;
}

function getIgnitionModule(modules: string[]) {
  const moduleDefinitions = modules
    .map((module) => `modules["${module}"] = m.contract("${module}");`)
    .join("\n  ");
  return `\
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("UpgradeDeployment", (m) => {
  const modules = {} as any;
  ${moduleDefinitions}

  return modules;
});`;
}

export async function main() {
  if (Bun.argv.length != 3) {
    console.error("Usage: bun satellite:upgrade <chainId>");
    process.exit(1);
  }

  const chainId = Bun.argv[2];
  const networkName = getNetworkName(chainId);

  const compiledModules = await getCompiledModules(chainId);
  const [deployedModules, satellite] = await getDeployedModules(chainId);

  const result = await compareModules(deployedModules, compiledModules);

  const [maintenanceActions, modules] = await getMaintenanceActions(result);

  const x = {} as Record<string, string>;
  for (const module of modules) {
    x[module] = module;
  }

  console.log("\nMaintenance actions are:", maintenanceActions(x));
  console.log("\n========================================\n");
  const confirm = prompt("Confirm that this is correct [y/N]:");
  if (confirm !== "y") {
    console.log("Aborting...");
    process.exit(0);
  }
  console.log("\n========================================\n");

  await Bun.write(
    "./ignition/modules/_autogenerated_upgrade.ts",
    getIgnitionModule(modules),
  );

  // TODO: handle ZkSync
  const deployResult = (
    await $`bun hardhat ignition deploy ./ignition/modules/_autogenerated_upgrade.ts --network ${networkName} --verify`
  ).text();

  fs.rmSync("./ignition/modules/_autogenerated_upgrade.ts");

  const addresses = {} as Record<string, string>;
  const regex = /UpgradeDeployment#(\w+) - (\w+)/;
  for (const line of deployResult.split("\n")) {
    if (regex.test(line)) {
      const [_, module, address] = line.match(regex)!;
      addresses[module] = address;
    }
  }

  const actions = maintenanceActions(addresses);
  console.log("\n========================================\n");
  console.log("Running maintenance actions...");
  console.log(actions);

  console.log(
    "res",
    await satellite.satelliteMaintenance(
      actions as any,
      "0x0000000000000000000000000000000000000000",
      "0x",
    ),
  );

  process.exit(0);
}

main();
