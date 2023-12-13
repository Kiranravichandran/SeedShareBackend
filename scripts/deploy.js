const { ethers } = require("hardhat");

async function main() {
  try {
    const signers = await ethers.getSigners();
    const deployer = signers[0];

    console.log("Deploying contracts with the account:", deployer.address);

    // Deploy SeedshareToken contract
    const SeedshareTokenContract = await ethers.getContractFactory("SeedshareToken");
    const seedshareTokenContract = await SeedshareTokenContract.deploy({ gasLimit: 5001 });

    const receipt = await seedshareTokenContract.deployed();
    console.log("Gas used:", receipt.gasUsed.toString());
    console.log("SeedshareToken deployed to:", seedshareTokenContract.address);

  } catch (error) {
    console.error("Error during deployment:", error);
  }
}

main();
