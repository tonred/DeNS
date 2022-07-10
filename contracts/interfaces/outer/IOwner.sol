pragma ton-solidity >= 0.61.2;

import "../../structures/DomainSetup.sol";
import "../../utils/TransferBackReason.sol";


interface IOwner {

    function onMinted(uint256 id, address nft, address owner, address manager, address creator) external;
    function onBurt(uint256 id, address nft, address owner, address manager) external;

    function onDomainRegistered(string path, DomainSetup setup) external;
    function onSubdomainCreated(string path, bool success, optional(TransferBackReason) reason) external;

    function onRenewed(string path, uint32 expireTime) external;
    function onUnreserved(string path, uint32 expireTime) external;

}
