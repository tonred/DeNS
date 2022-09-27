pragma ever-solidity ^0.63.0;

import "./Certificate.sol";
import "./Collection.sol";

import "tip4/contracts/implementation/4_2/JSONMetadataDynamicBase.sol";
import "tip4/contracts/implementation/4_3/NFTBase4_3.sol";


abstract contract NFTCertificate is NFTBase4_3, JSONMetadataDynamicBase, Certificate {

    modifier onlyManager() {
        require(msg.sender == _manager, ErrorCodes.IS_NOT_MANAGER);
        _;
    }

    function _initNFT(address owner, address manager, TvmCell indexCode, address creator) internal {
        _onInit4_3(owner, manager, indexCode);
        Collection(_root).onMint{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(_id, _owner, _manager, creator);
    }


    // TIP 4.1
    function changeOwner(
        address newOwner, address sendGasTo, mapping(address => CallbackParams) callbacks
    ) public virtual override onlyManager onActive {
        super.changeOwner(newOwner, sendGasTo, callbacks);
    }

    // TIP 4.1
    function changeManager(
        address newManager, address sendGasTo, mapping(address => CallbackParams) callbacks
    ) public virtual override onlyManager onActive {
        super.changeManager(newManager, sendGasTo, callbacks);
    }

    // TIP 4.1
    function transfer(
        address to, address sendGasTo, mapping(address => CallbackParams) callbacks
    ) public virtual override onlyManager onActive {
        super.transfer(to, sendGasTo, callbacks);
    }

    // TIP 4.2
    function getJson() public view responsible override returns (string json) {
        string targetStr = _target.isNone() ? "<Target is not set>" : format("{}", _target);
        string description = format("Everscale Domain '{}' -> {}", _path, targetStr);
        string source = "https://dens.ton.red/image/" + _path;
        string external_url = "https://dens.ton.red/" + _path;
        json = format(
            "{\"type\":\"Everscale Domain\",\"name\":\"{}\",\"description\":\"{}\",\"preview\":{\"source\":\"{}\",\"mimetype\":\"image/png\"},\"files\":[],\"external_url\":\"{}\",\"target\":\"{}\",\"init_time\":{},\"expire_time\":{}}",
            _path,          // name
            description,    // description
            source,         // source
            external_url,   // external_url
            targetStr,      // target
            _initTime,      // init_time
            _expireTime     // expire_time
        );
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} json;
    }

    // TIP6
    function supportsInterface(
        bytes4 interfaceID
    ) public view responsible override(NFTBase4_3, JSONMetadataDynamicBase) returns (bool support) {
        return {value: 0, flag: 64, bounce: false} (
            NFTBase4_3.supportsInterface(interfaceID) ||
            JSONMetadataDynamicBase.supportsInterface(interfaceID)
        );
    }

    function confiscate(address newOwner) public onlyRoot cashBack {
        _changeOwner(_owner, newOwner);
    }

    function expire() public onStatus(CertificateStatus.EXPIRED) {
        tvm.accept();
        _destroy();
    }


    function _getId() internal view override returns (uint256) {
        return _id;
    }

    function _getCollection() internal view override returns (address) {
        return _root;
    }

    function _getOwner() internal view override returns (address) {
        return _owner;
    }

    function _destroy() internal {
        Collection(_root).onBurn{
            value: Gas.ON_BURN_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(_id, _owner, _manager);
        _onBurn(_owner);
    }

    function _reserve() internal view override(NFTBase4_1, TransferUtils) {
        TransferUtils._reserve();
    }

    function _targetBalance() internal view inline virtual override returns (uint128);

}
