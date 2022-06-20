pragma ton-solidity >= 0.57.3;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;


abstract contract Certificate is PlatformBase {

    string public _path;

    address public _storage;
    address public _nft;
    address public _owner;

    uint32 public _startTime;
    uint32 public _endTime;
    address public _destination;  // todo rename ?
    mapping(string => string) public _records;  // or bytes => bytes


    function onCodeUpgrade(TvmCell input) private {
        tvm.resetStorage();
        TvmSlice slice = input.toSlice();
        (_root, /*type*/, /*remainingGasTo*/) = slice.decode(address, uint8, address);
        _platformCode = slice.loadRef();

        TvmCell initialData = slice.loadRef();
        _path = abi.decode(initialData, string);
        TvmCell initialParams = slice.loadRef();
        _onInit(initialParams);

        IStorage(_storage).deployNft{
            value: Gas.CERTIFICATE_DEPLOY_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false,
            callback: onDeployNft
        }(_path);
        // todo mint NFT
    }

    function _onInit(TvmCell initialParams) private virtual;

    function onDeployNft(address nft) public {
        _nft = nft;
    }

    function onNftInited(address nft) public {
        _nft = nft;
    }


    function getPath() public responsible returns (string path) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _path;
    }

    function getOwner() public responsible returns (address owner) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _owner;
    }

//    function isCorrectName(string name) public responsible returns (bool correct) {
//        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} checkName(name);
//    }


    function changeOwner(address newOwner) public onlyNFT cashBack {
        _changeOwner(newOwner);
    }

    function checkName(string name) public virtual returns (bool) {
        for (byte char : bytes(name)) {
            bool ok = (char > 60 && char < 123) || (char > 47 && char < 58) || (char == 45);  // a-z0-9-
            if (!ok) {
                return false;
            }
        }
        return true;
    }

    function confiscate(address newOwner) public onlyRoot cashBack {
        _changeOwner(newOwner);
    }

//    // todo
//    function destroy() public onlyOwner {
//        _destroy();
//    }


    function _changeOwner(address newOwner) private {  // todo in case of using remainingGasTo, use 128 flag due to emit
        emit ChangedOwner(_owner, newOwner);
        _owner = newOwner;
    }

    function _register(string path, address owner) internal {
        TvmCell params = abi.encode(_storage, owner);  // todo
        IStorage(_storage).registerSubdomain{
            value: Gas.REGISTER_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(path, params, callback, _path);
    }

//    function _destroy() private virtual {
//        // todo nft burn
//        IOwner(_owner).onDestroy{
//            value: 0,
//            flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.DESTROY_IF_ZERO,
//            bounce: false
//        }(_name, _parent);
//    }


    function prolongChild(string child) public responsible onlyCertificate(child) returns (uint32 endTime) {
//        uint32 pos = path.findLast(Constants.SEPARATOR).get();
//        string expectedParent = long.substr(0, pos);
//        require(expectedParent == _path, 69);
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _endTime;
    }

}
