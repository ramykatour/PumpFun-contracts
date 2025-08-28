const hre = require("hardhat");

async function main() {
  console.log("Deploying Pump Fun contracts to BSC Testnet...");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", balance.toString());

  const PumpFunFactory = await ethers.getContractFactory("PumpFunFactory");
  console.log("Deploying PumpFunFactory...");
  
  const feeRecipient = deployer.address;
  const factory = await PumpFunFactory.deploy(feeRecipient);
  await factory.waitForDeployment();
  const factoryAddress = await factory.getAddress();
  console.log("PumpFunFactory deployed to:", factoryAddress);

  const PumpFun = await ethers.getContractFactory("PumpFun");
  console.log("Deploying PumpFun main contract...");
  const pumpFun = await PumpFun.deploy(factoryAddress);
  await pumpFun.waitForDeployment();
  const pumpFunAddress = await pumpFun.getAddress();
  console.log("PumpFun main contract deployed to:", pumpFunAddress);

  console.log("Transferring factory ownership to PumpFun contract...");
  await factory.transferOwnership(pumpFunAddress);
  console.log("Factory ownership transferred to:", pumpFunAddress);

  console.log("\n=== Deployment Summary ===");
  console.log("Network:", hre.network.name);
  console.log("PumpFunFactory:", factoryAddress);
  console.log("PumpFun Main Contract:", pumpFunAddress);
  console.log("Fee Recipient:", feeRecipient);
  console.log("Deployer:", deployer.address);

  const deploymentInfo = {
    network: hre.network.name,
    pumpFunFactory: factoryAddress,
    pumpFunMain: pumpFunAddress,
    feeRecipient: feeRecipient,
    deployer: deployer.address,
    timestamp: new Date().toISOString()
  };

  const fs = require("fs");
  fs.writeFileSync(
    `deployment-${hre.network.name}.json`,
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log(`\nDeployment info saved to deployment-${hre.network.name}.json`);

  if (process.env.BSCSCAN_API_KEY) {
    console.log("\nVerifying contracts on BscScan...");
    
    try {
      await hre.run("verify:verify", {
        address: factoryAddress,
        constructorArguments: [feeRecipient],
        contract: "contracts/src/PumpFunFactory.sol:PumpFunFactory"
      });
      console.log("PumpFunFactory verified successfully");
    } catch (error) {
      console.log("Error verifying PumpFunFactory:", error.message);
    }

    try {
      await hre.run("verify:verify", {
        address: pumpFunAddress,
        constructorArguments: [factoryAddress],
        contract: "contracts/src/PumpFun.sol:PumpFun"
      });
      console.log("PumpFun verified successfully");
    } catch (error) {
      console.log("Error verifying PumpFun:", error.message);
    }
  }

  console.log("\n=== Deployment Complete ===");
  console.log("You can now interact with the Pump Fun contracts using the main contract address:", pumpFunAddress);
  console.log("\nNext steps:");
  console.log("1. Fund your account with BSC testnet BNB");
  console.log("2. Use the PumpFun main contract to create tokens");
  console.log("3. Test buying and selling tokens through the bonding curve");
  console.log("\nContract Addresses:");
  console.log("- PumpFun Main:", pumpFunAddress);
  console.log("- PumpFun Factory:", factoryAddress);
  console.log("- Fee Recipient:", feeRecipient);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });