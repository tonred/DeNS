pragma ton-solidity >= 0.61.2;

import "../utils/Constants.sol";


library Converter {

    function toDuration(uint128 amount, uint128 price) public returns (uint32) {
        return uint32(math.muldiv(Constants.DURATION_UNIT, amount, price));
    }

    function toAmount(uint128 duration, uint128 price) public returns (uint128) {
        return math.muldiv(duration, price, Constants.DURATION_UNIT);
    }

}
