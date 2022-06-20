pragma ton-solidity >= 0.57.3;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;


abstract contract DomainBase is Certificate {

    uint32 public _endTime;
    address public _destination;  // todo rename ?
    mapping(string => string) public _records;  // or bytes => bytes


    function getEndTime() public responsible returns (uint32 endTime) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _endTime;
    }

    function getDestination() public responsible returns (address destination) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _destination;
    }

    function getRecord(string key) public responsible returns (string record) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _records[key];
    }


    function setDestination(address destination) public onlyOwner cashBack {
        _destination = destination;
    }

    function addRecord(string key, string value) public onlyOwner cashBack {
        _records[key] = value;
    }

    function deleteRecord(string key) public onlyOwner cashBack {
        delete _records[key];
    }

    function register(string subdomain, address owner) public responsible virtual;

    function prolongSubdomain(address subdomain, uint32 endTime) public onlyOwner {
        require(endTime <= _endTime, 69);
        ISubdomain(subdomain).prolong{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: true
        }(msg.sender, endTime);
    }

    function onExpire() public {
        require(now > _endTime && _endTime != 0, 69);
        _destroy();
    }

}
