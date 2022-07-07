pragma ton-solidity >= 0.61.2;


library NameChecker {

    function isCorrectName(string name, uint32 maxNameLength) public pure returns (bool) {
        uint32 length = name.byteLength();
        if (length == 0 || length > maxNameLength) {
            return false;
        }
        for (byte char : bytes(name)) {
            bool ok = (char > 0x3c && char < 0x7b) || (char > 0x2f && char < 0x3a) || (char == 0x2d);  // a-z0-9-
            if (!ok) {
                return false;
            }
        }
        return true;
    }

}
