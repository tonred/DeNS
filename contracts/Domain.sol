pragma ton-solidity >= 0.57.3;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;


contract Domain is DomainBase {

    uint128 public _startPrice;
    uint128 public _currentPrice;
    uint32 public _startTime;
    uint32 public _endTime;
    bool public _inAuction;


    function _onInit(TvmCell initialParams) private override {
        uint32 duration;
        (_storage, _startPrice, duration) = abi.decode(initialParams, (address, uint128, uint32));
        _startPrice = now;
        _endTime = now + duration;
        _currentPrice = _startPrice;
    }


    function register(string name, address owner) public responsible onlyOwner {
        require(checkName(name), 69);
        _reserve();
        _register(_path + Constants.SEPARATOR + name, owner);
        emit NewSubdomain(name);
    }

}
