const { Web3 } = require('web3');
const contract = require('./build/contracts/CertificateManager.json');

async function main() {
  try {
    // Connect to the local Ethereum network (e.g., Ganache)
    const web3 = new Web3('http://localhost:8545');

    // Get the network ID
    const networkId = await web3.eth.net.getId();

    // Get the contract address for the current network
    const deployedNetwork = contract.networks[networkId];
    if (!deployedNetwork) {
      throw new Error('Contract not deployed on the current network');
    }

    // Create an instance of the CertificateManager contract
    const certificateManagerContract = new web3.eth.Contract(
      contract.abi,
      deployedNetwork.address
    );

    // Get the list of accounts
    const accounts = await web3.eth.getAccounts();
    const owner = accounts[0];
    const signer1 = accounts[1];
    const signer2 = accounts[2];

    // Helper function to log test results
    function logTest(testName, result) {
      console.log(`Test: ${testName} - ${result ? 'PASSED' : 'FAILED'}`);
    }

    // Test: Add signers
    async function testAddSigners() {
      await certificateManagerContract.methods.addSigner(signer1).send({ from: owner });
      await certificateManagerContract.methods.addSigner(signer2).send({ from: owner });
      const signersCount = await certificateManagerContract.methods.signersCount().call();
      logTest('Add signers', signersCount == 2);
    }

    // Test: Set minimum signers
    async function testSetMinimumSigners() {
      await certificateManagerContract.methods.setMinimumSigners(2).send({ from: owner });
      const minimumSigners = await certificateManagerContract.methods.minimumSigners().call();
      logTest('Set minimum signers', minimumSigners == 2);
    }

    // Test: Create certificate
    async function testCreateCertificate() {
      const result = await certificateManagerContract.methods.createCertificate("Test Certificate Data").send({ from: signer1 });
      const certificateCreatedEvent = result.events.CertificateCreated;
      logTest('Create certificate', certificateCreatedEvent != null);
      return certificateCreatedEvent.returnValues.uuid;
    }

    // Test: Sign certificate
    async function testSignCertificate(uuid) {
      await certificateManagerContract.methods.signCertificate(uuid).send({ from: signer2 });
      const certificate = await certificateManagerContract.methods.getCertificate(uuid).call();
      logTest('Sign certificate', certificate[2] == 1 && certificate[3] == 2);
    }

    // Test: Get unsigned certificates
    async function testGetUnsignedCertificates() {
      const unsignedCertificates = await certificateManagerContract.methods.getUnsignedCertificates().call();
      logTest('Get unsigned certificates', unsignedCertificates.length == 0);
    }

    // Test: Change owner
    async function testChangeOwner() {
      const newOwner = accounts[3];
      await certificateManagerContract.methods.changeOwner(newOwner).send({ from: owner });
      const currentOwner = await certificateManagerContract.methods.owner().call();
      logTest('Change owner', currentOwner.toLowerCase() === newOwner.toLowerCase());
    }

    // Run tests
    await testAddSigners();
    await testSetMinimumSigners();
    const uuid = await testCreateCertificate();
    await testSignCertificate(uuid);
    await testGetUnsignedCertificates();
    await testChangeOwner();

  } catch (error) {
    console.error('Error:', error);
  }
}

main();