pragma ton-solidity >= 0.57.3;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;


contract Subdomain is DomainBase {

    address public _parent;


    modifier onlyParent() {
        require(msg.sender == _parent, 69);
        _;
    }

    function _onInit(TvmCell initialParams) private override {
        (_storage, _owner, _endTime) = abi.decode(initialParams, (address, address, uint32));
//        (_owner, _endTime, _domain) = abi.decode(initialParams, (address, uint32, address));
    }


    // todo so subdomain prolong via main domain or via parent? allow domain to prolong subdomain and remove subdomain contract?
    function register(string subdomain, address owner) public responsible onlyOwner {
        require(checkName(name), 69);
        _reserve();
        TvmCell initialParams = abi.encode(owner, _endTime, _domain);
        address subdomain = _register(name, initialParams, tvm.code());
        emit NewSubdomain(subdomain, name);
        return {value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false} subdomain;
    }

    function prolong(uint32 endTime, address remainingGasTo) public onlyParent {
        // avoid cutting end time by parent
        if (endTime > _endTime) {
            _endTime = endTime;
        }
        remainingGasTo.transfer({value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false});
    }

    function prolong() public {
        require(msg.value > 69, 69);  // must have to avoid destroying in onBounce
        IDomain(_domain).prolongSubdomain{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: true,
            callback: SubDomain.onProlong
        }(_name, _parent);
    }

    function onProlong(uint endTime) public onlyDomain {
        _endTime = endTime;
    }

//    onBounce(TvmSlice slice) external {
//        uint32 functionId = slice.decode(uint32);
//        if (functionId == tvm.functionId(IDomain.prolongSubdomain)) {
//            // no main domain, destroy
//            _destroy();
//        }
//    }

}
