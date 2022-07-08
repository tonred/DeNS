pragma ton-solidity >= 0.61.2;

import "../../structures/DomainSetup.sol";
import "../../utils/TransferCanselReason.sol";


interface IOwner {
    function onMinted(uint256 id, address nft, address owner, address manager, address creator) external;
    function onBurt(uint256 id, address nft, address owner, address manager) external;
//    // todo down methods where
//    function onRenewed(string path, uint32 expireTime) external;
    function onUnreserved(string path, uint32 expireTime) external;

    // todo order
    function onDomainRegistered(string path, DomainSetup setup) external;
    function onSubdomainCreated(string path, bool success, optional(TransferCanselReason) reason) external;
}
