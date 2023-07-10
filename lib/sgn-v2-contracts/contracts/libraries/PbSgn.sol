// SPDX-License-Identifier: GPL-3.0-only

// Code generated by protoc-gen-sol. DO NOT EDIT.
// source: contracts/libraries/proto/sgn.proto
pragma solidity 0.8.17;
import "./Pb.sol";

library PbSgn {
    using Pb for Pb.Buffer; // so we can call Pb funcs on Buffer obj

    struct Withdrawal {
        address account; // tag: 1
        address token; // tag: 2
        uint256 cumulativeAmount; // tag: 3
    } // end struct Withdrawal

    function decWithdrawal(bytes memory raw) internal pure returns (Withdrawal memory m) {
        Pb.Buffer memory buf = Pb.fromBytes(raw);

        uint256 tag;
        Pb.WireType wire;
        while (buf.hasMore()) {
            (tag, wire) = buf.decKey();
            if (false) {}
            // solidity has no switch/case
            else if (tag == 1) {
                m.account = Pb._address(buf.decBytes());
            } else if (tag == 2) {
                m.token = Pb._address(buf.decBytes());
            } else if (tag == 3) {
                m.cumulativeAmount = Pb._uint256(buf.decBytes());
            } else {
                buf.skipValue(wire);
            } // skip value of unknown tag
        }
    } // end decoder Withdrawal
}
