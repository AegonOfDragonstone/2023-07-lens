// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import './base/BaseTest.t.sol';
import './MetaTxNegatives.t.sol';

contract ChangeDelegatedExecutorsConfigTest_CurrentConfig is BaseTest {
    uint256 constant delegatorProfileOwnerPk = 0xDE1E6A708;
    address delegatorProfileOwner;
    uint256 delegatorProfileId;

    function setUp() public virtual override {
        super.setUp();

        delegatorProfileOwner = vm.addr(delegatorProfileOwnerPk);
        delegatorProfileId = _createProfile(delegatorProfileOwner);

        uint64 configNumberInit = hub.getDelegatedExecutorsConfigNumber(delegatorProfileId);
        uint64 maxConfigNumberInit = hub.getDelegatedExecutorsMaxConfigNumberSet(
            delegatorProfileId
        );
    }

    //////////////////////////////////////////////////////////////////////
    // changeDelegatedExecutorsConfig - Current config - Negatives
    //////////////////////////////////////////////////////////////////////

    function testCannotChangeDelegatedExecutorsConfigWhenProtocolIsPaused(
        address executor,
        bool approval
    ) public {
        vm.prank(governance);

        hub.setState(DataTypes.ProtocolState.Paused);

        vm.expectRevert(Errors.Paused.selector);

        _changeCurrentDelegatedExecutorsConfig(
            delegatorProfileOwnerPk,
            delegatorProfileId,
            _toAddressArray(executor),
            _toBoolArray(approval)
        );
    }

    function testCannotChangeDelegatedExecutorsConfigPassingDifferentAmountOfExecutorsAndApprovals(
        address firstExecutor,
        address secondExecutor,
        bool approval
    ) public {
        vm.expectRevert(Errors.ArrayMismatch.selector);

        _changeCurrentDelegatedExecutorsConfig(
            delegatorProfileOwnerPk,
            delegatorProfileId,
            _toAddressArray(firstExecutor, secondExecutor),
            _toBoolArray(approval)
        );
    }

    function testCannotChangeDelegatedExecutorsConfigIfCallerIsNotDelegatorProfileOwner(
        uint256 nonOwnerPk,
        address executor,
        bool approval
    ) public virtual {
        nonOwnerPk = bound(nonOwnerPk, 1, ISSECP256K1_CURVE_ORDER - 1);
        vm.assume(nonOwnerPk != delegatorProfileOwnerPk);

        vm.expectRevert(Errors.NotProfileOwner.selector);

        _changeCurrentDelegatedExecutorsConfig(
            nonOwnerPk,
            delegatorProfileId,
            _toAddressArray(executor),
            _toBoolArray(approval)
        );
    }

    function testCannotChangeDelegatedExecutorsConfigIfDelegatorProfileDoesNotExist(
        uint256 unexistentProfileId,
        address executor,
        bool approval
    ) public {
        vm.assume(!hub.exists(unexistentProfileId));

        vm.expectRevert(Errors.TokenDoesNotExist.selector);

        _changeCurrentDelegatedExecutorsConfig(
            delegatorProfileOwnerPk,
            unexistentProfileId,
            _toAddressArray(executor),
            _toBoolArray(approval)
        );
    }

    //////////////////////////////////////////////////////////////////////
    // changeDelegatedExecutorsConfig - Current config - Scenarios
    //////////////////////////////////////////////////////////////////////

    function testDelegatedExecutorsConfigIsClearedAfter(address newProfileOwner, address executor)
        public
    {
        vm.assume(newProfileOwner != address(0));
        vm.assume(newProfileOwner != delegatorProfileOwner);

        _changeCurrentDelegatedExecutorsConfig(
            delegatorProfileOwnerPk,
            delegatorProfileId,
            _toAddressArray(executor),
            _toBoolArray(true)
        );

        uint64 maxConfigSetBeforeTranster = hub.getDelegatedExecutorsMaxConfigNumberSet(
            delegatorProfileId
        );

        vm.prank(delegatorProfileOwner);
        hub.transferFrom(delegatorProfileOwner, newProfileOwner, delegatorProfileId);

        uint64 expectedMaxConfigSetAfterTransfer = maxConfigSetBeforeTranster + 1;

        assertEq(
            expectedMaxConfigSetAfterTransfer,
            hub.getDelegatedExecutorsMaxConfigNumberSet(delegatorProfileId)
        );
        assertEq(
            expectedMaxConfigSetAfterTransfer,
            hub.getDelegatedExecutorsConfigNumber(delegatorProfileId)
        );

        assertFalse(hub.isDelegatedExecutorApproved(delegatorProfileId, executor));
    }

    function testDelegatedExecutorsConfigIsApprovedAfterChangingItsApprovalToTrue(address executor)
        public
    {
        _changeCurrentDelegatedExecutorsConfig(
            delegatorProfileOwnerPk,
            delegatorProfileId,
            _toAddressArray(executor),
            _toBoolArray(true)
        );

        assertTrue(hub.isDelegatedExecutorApproved(delegatorProfileId, executor));
    }

    //////////////////////////////////////////////////////////////////////

    function _changeCurrentDelegatedExecutorsConfig(
        uint256 pk,
        uint256 delegatorProfileId,
        address[] memory executors,
        bool[] memory approvals
    ) private {
        _changeDelegatedExecutorsConfig(pk, delegatorProfileId, executors, approvals, 0, false);
    }

    function _changeDelegatedExecutorsConfig(
        uint256 pk,
        uint256 delegatorProfileId,
        address[] memory executors,
        bool[] memory approvals,
        uint64 configNumber,
        bool switchToGivenConfig
    ) internal virtual {
        vm.prank(vm.addr(pk));
        hub.changeDelegatedExecutorsConfig(delegatorProfileId, executors, approvals);
    }
}

contract ChangeDelegatedExecutorsConfigTest_GivenConfig is
    ChangeDelegatedExecutorsConfigTest_CurrentConfig
{
    //////////////////////////////////////////////////////////////////////
    // changeDelegatedExecutorsConfig - Given config - Negatives
    //////////////////////////////////////////////////////////////////////

    function testCannotChangeDelegatedExecutorsConfigIfPassedConfigNumberIsBiggerThanMaxAvailableOne(
        uint64 invalidConfigNumber,
        address executor,
        bool approval
    ) public {
        uint64 maxAvailableConfigNumber = hub.getDelegatedExecutorsMaxConfigNumberSet(
            delegatorProfileId
        ) + 1;
        uint64 fistInvalidConfigNumber = maxAvailableConfigNumber + 1;
        invalidConfigNumber = uint64(
            bound(invalidConfigNumber, fistInvalidConfigNumber, type(uint64).max)
        );

        vm.expectRevert(Errors.InvalidParameter.selector);

        _changeDelegatedExecutorsConfig(
            delegatorProfileOwnerPk,
            delegatorProfileId,
            _toAddressArray(executor),
            _toBoolArray(approval),
            invalidConfigNumber,
            false
        );
    }

    //////////////////////////////////////////////////////////////////////
    // changeDelegatedExecutorsConfig - Given config - Negatives
    //////////////////////////////////////////////////////////////////////

    function testChangeMaxAvailableDelegatedExecutorsConfigWithoutSwitchingToIt(address executor)
        public
    {
        uint64 configNumberBefore = hub.getDelegatedExecutorsConfigNumber(delegatorProfileId);
        uint64 maxConfigNumberBefore = hub.getDelegatedExecutorsMaxConfigNumberSet(
            delegatorProfileId
        );
        uint64 maxAvailableConfigNumber = maxConfigNumberBefore + 1;

        vm.expectEmit(true, true, true, true, address(hub));
        emit Events.DelegatedExecutorsConfigChanged({
            delegatorProfileId: delegatorProfileId,
            configNumber: maxAvailableConfigNumber,
            executors: _toAddressArray(executor),
            approvals: _toBoolArray(true),
            configSwitched: false
        });

        _changeDelegatedExecutorsConfig({
            pk: delegatorProfileOwnerPk,
            delegatorProfileId: delegatorProfileId,
            executors: _toAddressArray(executor),
            approvals: _toBoolArray(true),
            configNumber: maxAvailableConfigNumber,
            switchToGivenConfig: false
        });

        assertEq(
            maxAvailableConfigNumber,
            hub.getDelegatedExecutorsMaxConfigNumberSet(delegatorProfileId)
        );
        assertEq(configNumberBefore, hub.getDelegatedExecutorsConfigNumber(delegatorProfileId));

        assertTrue(
            hub.isDelegatedExecutorApproved(delegatorProfileId, executor, maxAvailableConfigNumber)
        );
        assertFalse(hub.isDelegatedExecutorApproved(delegatorProfileId, executor));
    }

    function testChangeMaxAvailableDelegatedExecutorsConfigSwitchingToIt(address executor) public {
        uint64 maxConfigNumberBefore = hub.getDelegatedExecutorsMaxConfigNumberSet(
            delegatorProfileId
        );
        uint64 maxAvailableConfigNumber = maxConfigNumberBefore + 1;

        vm.expectEmit(true, true, true, true, address(hub));
        emit Events.DelegatedExecutorsConfigChanged({
            delegatorProfileId: delegatorProfileId,
            configNumber: maxAvailableConfigNumber,
            executors: _toAddressArray(executor),
            approvals: _toBoolArray(true),
            configSwitched: true
        });

        _changeDelegatedExecutorsConfig({
            pk: delegatorProfileOwnerPk,
            delegatorProfileId: delegatorProfileId,
            executors: _toAddressArray(executor),
            approvals: _toBoolArray(true),
            configNumber: maxAvailableConfigNumber,
            switchToGivenConfig: true
        });

        assertEq(
            maxAvailableConfigNumber,
            hub.getDelegatedExecutorsMaxConfigNumberSet(delegatorProfileId)
        );
        assertEq(
            maxAvailableConfigNumber,
            hub.getDelegatedExecutorsConfigNumber(delegatorProfileId)
        );

        assertTrue(
            hub.isDelegatedExecutorApproved(delegatorProfileId, executor, maxAvailableConfigNumber)
        );
        assertTrue(hub.isDelegatedExecutorApproved(delegatorProfileId, executor));
    }

    function testChangeToPreviousConfiguration(address executor) public {
        uint64 firstConfigNumberSet = hub.getDelegatedExecutorsMaxConfigNumberSet(
            delegatorProfileId
        ) + 1;
        _changeDelegatedExecutorsConfig({
            pk: delegatorProfileOwnerPk,
            delegatorProfileId: delegatorProfileId,
            executors: _toAddressArray(executor),
            approvals: _toBoolArray(true),
            configNumber: firstConfigNumberSet,
            switchToGivenConfig: true
        });

        uint64 secondConfigNumberSet = firstConfigNumberSet + 1;
        _refreshCachedNonce(delegatorProfileOwner);
        _changeDelegatedExecutorsConfig({
            pk: delegatorProfileOwnerPk,
            delegatorProfileId: delegatorProfileId,
            executors: _toAddressArray(executor),
            approvals: _toBoolArray(true),
            configNumber: secondConfigNumberSet,
            switchToGivenConfig: true
        });

        uint64 thirdConfigNumberSet = secondConfigNumberSet + 1;
        _refreshCachedNonce(delegatorProfileOwner);
        _changeDelegatedExecutorsConfig({
            pk: delegatorProfileOwnerPk,
            delegatorProfileId: delegatorProfileId,
            executors: _toAddressArray(executor),
            approvals: _toBoolArray(true),
            configNumber: thirdConfigNumberSet,
            switchToGivenConfig: true
        });

        uint64 fourthConfigNumberSet = thirdConfigNumberSet + 1;
        _refreshCachedNonce(delegatorProfileOwner);

        _changeDelegatedExecutorsConfig({
            pk: delegatorProfileOwnerPk,
            delegatorProfileId: delegatorProfileId,
            executors: _toAddressArray(executor),
            approvals: _toBoolArray(true),
            configNumber: fourthConfigNumberSet,
            switchToGivenConfig: true
        });

        // After creating new four configurations, switch to the second one.
        _refreshCachedNonce(delegatorProfileOwner);
        _changeDelegatedExecutorsConfig({
            pk: delegatorProfileOwnerPk,
            delegatorProfileId: delegatorProfileId,
            executors: new address[](0),
            approvals: new bool[](0),
            configNumber: secondConfigNumberSet,
            switchToGivenConfig: true
        });

        // Switch to fourth configuration, now the previous configuration is the second one.
        _refreshCachedNonce(delegatorProfileOwner);
        _changeDelegatedExecutorsConfig({
            pk: delegatorProfileOwnerPk,
            delegatorProfileId: delegatorProfileId,
            executors: new address[](0),
            approvals: new bool[](0),
            configNumber: fourthConfigNumberSet,
            switchToGivenConfig: true
        });

        // Switch to the previous configuration.
        _refreshCachedNonce(delegatorProfileOwner);
        _changeDelegatedExecutorsConfig({
            pk: delegatorProfileOwnerPk,
            delegatorProfileId: delegatorProfileId,
            executors: new address[](0),
            approvals: new bool[](0),
            configNumber: hub.getDelegatedExecutorsPrevConfigNumber(delegatorProfileId),
            switchToGivenConfig: true
        });

        assertEq(
            fourthConfigNumberSet,
            hub.getDelegatedExecutorsMaxConfigNumberSet(delegatorProfileId)
        );
        assertEq(secondConfigNumberSet, hub.getDelegatedExecutorsConfigNumber(delegatorProfileId));
    }

    //////////////////////////////////////////////////////////////////////

    function _refreshCachedNonce(address signer) internal virtual {
        // Nothing to do here, this is meant to be overriden by the meta-tx tests.
    }

    function _changeDelegatedExecutorsConfig(
        uint256 pk,
        uint256 delegatorProfileId,
        address[] memory executors,
        bool[] memory approvals,
        uint64 configNumber,
        bool switchToGivenConfig
    ) internal virtual override {
        vm.prank(vm.addr(pk));
        hub.changeDelegatedExecutorsConfig(
            delegatorProfileId,
            executors,
            approvals,
            configNumber,
            switchToGivenConfig
        );
    }
}

contract ChangeDelegatedExecutorsConfigTest_MetaTx is
    ChangeDelegatedExecutorsConfigTest_GivenConfig,
    MetaTxNegatives
{
    mapping(address => uint256) cachedNonceByAddress;

    function setUp()
        public
        override(ChangeDelegatedExecutorsConfigTest_CurrentConfig, MetaTxNegatives)
    {
        ChangeDelegatedExecutorsConfigTest_CurrentConfig.setUp();
        MetaTxNegatives.setUp();

        cachedNonceByAddress[delegatorProfileOwner] = _getSigNonce(delegatorProfileOwner);
    }

    function testCannotChangeDelegatedExecutorsConfigIfCallerIsNotDelegatorProfileOwner(
        uint256 nonOwnerPk,
        address executor,
        bool approval
    ) public override {
        nonOwnerPk = bound(nonOwnerPk, 1, ISSECP256K1_CURVE_ORDER - 1);
        vm.assume(nonOwnerPk != delegatorProfileOwnerPk);

        vm.expectRevert(Errors.SignatureInvalid.selector);

        _changeDelegatedExecutorsConfig(
            nonOwnerPk,
            delegatorProfileId,
            _toAddressArray(executor),
            _toBoolArray(approval),
            0,
            false
        );
    }

    //////////////////////////////////////////////////////////////////////

    function _refreshCachedNonce(address signer) internal override {
        cachedNonceByAddress[signer] = _getSigNonce(signer);
    }

    function _changeDelegatedExecutorsConfig(
        uint256 pk,
        uint256 delegatorProfileId,
        address[] memory executors,
        bool[] memory approvals,
        uint64 configNumber,
        bool switchToGivenConfig
    ) internal override {
        address signerAddress = vm.addr(pk);
        hub.changeDelegatedExecutorsConfigWithSig(
            _getSignedData({
                signerPk: pk,
                delegatorProfileId: delegatorProfileId,
                executors: executors,
                approvals: approvals,
                configNumber: configNumber,
                switchToGivenConfig: switchToGivenConfig,
                nonce: cachedNonceByAddress[signerAddress],
                deadline: type(uint256).max
            })
        );
    }

    function _getSignedData(
        uint256 signerPk,
        uint256 delegatorProfileId,
        address[] memory executors,
        bool[] memory approvals,
        uint64 configNumber,
        bool switchToGivenConfig,
        uint256 nonce,
        uint256 deadline
    ) private returns (DataTypes.ChangeDelegatedExecutorsConfigWithSigData memory) {
        return
            DataTypes.ChangeDelegatedExecutorsConfigWithSigData({
                delegatorProfileId: delegatorProfileId,
                executors: executors,
                approvals: approvals,
                configNumber: configNumber,
                switchToGivenConfig: switchToGivenConfig,
                sig: _getSigStruct({
                    pKey: signerPk,
                    digest: _calculateChangeDelegatedExecutorsConfigWithSigDigest(
                        delegatorProfileId,
                        executors,
                        approvals,
                        configNumber,
                        switchToGivenConfig,
                        nonce,
                        deadline
                    ),
                    deadline: deadline
                })
            });
    }

    function _calculateChangeDelegatedExecutorsConfigWithSigDigest(
        uint256 delegatorProfileId,
        address[] memory executors,
        bool[] memory approvals,
        uint64 configNumber,
        bool switchToGivenConfig,
        uint256 nonce,
        uint256 deadline
    ) private returns (bytes32) {
        return
            _calculateDigest(
                keccak256(
                    abi.encode(
                        CHANGE_DELEGATED_EXECUTORS_CONFIG_WITH_SIG_TYPEHASH,
                        delegatorProfileId,
                        abi.encodePacked(executors),
                        abi.encodePacked(approvals),
                        configNumber,
                        switchToGivenConfig,
                        nonce,
                        deadline
                    )
                )
            );
    }

    function _executeMetaTx(
        uint256 signerPk,
        uint256 nonce,
        uint256 deadline
    ) internal override {
        address signerAddress = vm.addr(signerPk);
        hub.changeDelegatedExecutorsConfigWithSig(
            _getSignedData({
                signerPk: signerPk,
                delegatorProfileId: delegatorProfileId,
                executors: _toAddressArray(address(0xC0FFEE)),
                approvals: _toBoolArray(true),
                configNumber: 0,
                switchToGivenConfig: false,
                nonce: nonce,
                deadline: deadline
            })
        );
    }

    function _getDefaultMetaTxSignerPk() internal override returns (uint256) {
        return delegatorProfileOwnerPk;
    }
}
