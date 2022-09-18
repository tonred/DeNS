pragma ever-solidity ^0.63.0;


library NameChecker {

    function isCorrectName(string name, uint32 maxNameLength) public returns (bool) {
        uint32 length = name.byteLength();
        if (length == 0 || length > maxNameLength) {
            return false;
        }
        bytes nameAsBytes = bytes(name);
        if (nameAsBytes[0] == 0x2d || nameAsBytes[length - 1] == 0x2d) {
            // starts or ends with char '-'
            return false;
        }
        for (byte char : nameAsBytes) {
            bool ok = (char >= 0x61 && char <= 0x7a) || (char >= 0x30 && char <= 0x39) || (char == 0x2d);  // a-z0-9-
            if (!ok) {
                return false;
            }
        }
        return true;
    }

    function isOnlyLetters(string name) public returns (bool) {
        for (byte char : bytes(name)) {
            if (!(char >= 0x61 && char <= 0x7a)) {
                return false;
            }
        }
        return true;
    }

}
