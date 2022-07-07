pragma ton-solidity >= 0.61.2;


interface ICertificate {
    function prolongSubdomain(address subdomain) external;
    function confiscate(address newOwner) external;
}
