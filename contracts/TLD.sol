pragma ton-solidity >= 0.57.3;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;


contract TLD is Certificate {
    uint32 constant DURATION_UNIT = 1 days;

    uint32 public _minDuration;
    uint32 public _maxDuration;
    uint128[] public _prices;
    uint32[] public _unlockTimes;
    TvmCell public _domainCode;


    function _onInit(TvmCell initialParams) private override {
        _owner = _root;
        (_minDuration, _maxDuration, _prices, _unlockTimes, _domainCode) =
            abi.decode(initialParams, (uint32, uint32, uint128[], uint32[], TvmCell));
        require(_prices.length > 0 && _minDuration <= _maxDuration, 69);
    }


    function register(string name, uint32 duration, address owner) public cashBack {
        require(checkName(name), 69);
        require(duration >= _minDuration && duration <= _maxDuration, 69);
        uint32 length = name.byteLength();
        require(isUnlocked(length), 69);

        uint128 startPrice = calcPrice(length, duration);
        uint32 endTime = duration * DURATION_UNIT;
        TvmCell initialParams = abi.encode(owner, endTime, startPrice, _subdomainCode);
        address domain = _register(name, initialParams, _domainCode);
        emit NewDomain(domain, name);
    }

    function isUnlocked(uint32 length) public returns (bool) {
        if (length < _unlockTimes.length) {
            return now > _unlockTimes[length];
        }
        return true;
    }

    function calcPrice(uint32 length, uint32 duration) public returns (uint128) {
        length = math.min(length, _prices.length);
        return _prices[length] * duration;
    }

}
