pragma solidity ^0.8.0;

contract CertificateManager {
    // Struct to represent a certificate
    struct Certificate {
        bytes16 uuid;
        string data;
        uint8 status;
        uint8 signs;
        address creator;
        mapping(address => bool) signers;
    }

    // Enum for certificate status
    enum Status { Unverified, Verified, Revoked }

    // State variables
    address public owner;
    uint8 public minimumSigners;
    address[5] public signersList;
    uint8 public signersCount;
    mapping(bytes16 => Certificate) public certificates;
    bytes16[] public certificateIds;

    // Events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event CertificateCreated(bytes16 indexed uuid, address creator);
    event CertificateSigned(bytes16 indexed uuid, address signer);
    event CertificateVerified(bytes16 indexed uuid);

    // Constructor
    constructor() {
        owner = msg.sender;
        minimumSigners = 1;
    }

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlySigner() {
        bool isSigner = false;
        for (uint8 i = 0; i < signersCount; i++) {
            if (signersList[i] == msg.sender) {
                isSigner = true;
                break;
            }
        }
        require(isSigner, "Only signers can call this function");
        _;
    }

    // Functions
    function changeOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setMinimumSigners(uint8 _minimumSigners) public onlyOwner {
        require(_minimumSigners > 0 && _minimumSigners <= 5, "Invalid minimum signers count");
        minimumSigners = _minimumSigners;
    }

    function addSigner(address _signer) public onlyOwner {
        require(signersCount < 5, "Maximum number of signers reached");
        for (uint8 i = 0; i < signersCount; i++) {
            require(signersList[i] != _signer, "Signer already exists");
        }
        signersList[signersCount] = _signer;
        signersCount++;
    }

    function createCertificate(string memory _data) public onlySigner returns (bytes16) {
        bytes16 uuid = bytes16(keccak256(abi.encodePacked(block.timestamp, msg.sender, _data)));
        Certificate storage newCertificate = certificates[uuid];
        newCertificate.uuid = uuid;
        newCertificate.data = _data;
        newCertificate.status = uint8(Status.Unverified);
        newCertificate.signs = 0;
        newCertificate.creator = msg.sender;
        certificateIds.push(uuid);
        emit CertificateCreated(uuid, msg.sender);
        return uuid;
    }

    function signCertificate(bytes16 _uuid) public onlySigner {
        Certificate storage cert = certificates[_uuid];
        require(cert.uuid != bytes16(0), "Certificate does not exist");
        require(cert.status == uint8(Status.Unverified), "Certificate is not in unverified state");
        require(cert.creator != msg.sender, "Certificate creator cannot sign");
        require(!cert.signers[msg.sender], "Signer has already signed this certificate");

        cert.signers[msg.sender] = true;
        cert.signs++;
        emit CertificateSigned(_uuid, msg.sender);

        if (cert.signs >= minimumSigners) {
            cert.status = uint8(Status.Verified);
            emit CertificateVerified(_uuid);
        }
    }

    function getUnsignedCertificates() public view returns (bytes16[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < certificateIds.length; i++) {
            if (certificates[certificateIds[i]].status == uint8(Status.Unverified)) {
                count++;
            }
        }

        bytes16[] memory unsignedCertificates = new bytes16[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < certificateIds.length; i++) {
            if (certificates[certificateIds[i]].status == uint8(Status.Unverified)) {
                unsignedCertificates[index] = certificateIds[i];
                index++;
            }
        }

        return unsignedCertificates;
    }

    function getCertificate(bytes16 _uuid) public view returns (bytes16, string memory, uint8, uint8, address) {
        Certificate storage cert = certificates[_uuid];
        require(cert.uuid != bytes16(0), "Certificate does not exist");
        return (cert.uuid, cert.data, cert.status, cert.signs, cert.creator);
    }
}