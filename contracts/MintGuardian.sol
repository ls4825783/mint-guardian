// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title MintGuardian — Agent ID-gated registry of verified free-mint reports
/// @notice Agent ID holders (ERC721 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F on BSC
///         mainnet) can publish and endorse safety reports about BSC free mints.
///         Anyone can read. No payments, no token, no minting — registry only.
/// @dev The Agent ID registry address is a constructor parameter so the same
///      bytecode can be tested against a mock ERC721 on BSC testnet (chain 97),
///      where the real registry does not exist. Mainnet deployments MUST pass
///      0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F. There is no test-only bypass
///      flag anywhere in this contract.
interface IERC721Minimal {
    function balanceOf(address owner) external view returns (uint256);
}

contract MintGuardian {
    // ------------------------------------------------------------------------
    // Types
    // ------------------------------------------------------------------------

    /// @dev 0 = Safe, 1 = Risky, 2 = Scam
    enum Verdict {
        Safe,
        Risky,
        Scam
    }

    struct Report {
        address mintContract; // contract of the mint being reported
        string name; // human-readable project name
        Verdict verdict; // 0 Safe / 1 Risky / 2 Scam
        string evidenceURI; // link to evidence (tx hash, audit, write-up)
        address reporter; // Agent ID holder who filed the report
        uint256 createdAt; // block timestamp of submission
        uint256 endorsements; // number of distinct Agent ID holders endorsing
    }

    // ------------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------------

    /// @notice ERC721 registry used for Agent ID gating.
    ///         Mainnet: 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
    address public immutable agentIdRegistry;

    address public owner;
    bool public paused;

    Report[] private _reports;

    /// @dev mintContract => report ids filed about it
    mapping(address => uint256[]) private _reportsByMint;
    /// @dev reporter => mintContract => already reported (one report per holder per mint)
    mapping(address => mapping(address => bool)) private _hasReported;
    /// @dev reportId => endorser => endorsed
    mapping(uint256 => mapping(address => bool)) private _hasEndorsed;

    // ------------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------------

    event ReportSubmitted(
        uint256 indexed reportId,
        address indexed mintContract,
        address indexed reporter,
        Verdict verdict
    );
    event Endorsed(uint256 indexed reportId, address indexed endorser);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ------------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------------

    error NotAgentHolder();
    error NotOwner();
    error PausedContract();
    error InvalidVerdict();
    error ZeroAddress();
    error EmptyName();
    error AlreadyReported();
    error ReportNotFound();
    error AlreadyEndorsed();
    error SelfEndorse();

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------

    /// @param _agentIdRegistry ERC721 Agent ID registry.
    ///        Mainnet: 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
    constructor(address _agentIdRegistry) {
        if (_agentIdRegistry == address(0)) revert ZeroAddress();
        agentIdRegistry = _agentIdRegistry;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ------------------------------------------------------------------------
    // Modifiers
    // ------------------------------------------------------------------------

    modifier onlyAgentHolder() {
        if (!isAgentHolder(msg.sender)) revert NotAgentHolder();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PausedContract();
        _;
    }

    // ------------------------------------------------------------------------
    // Views — Agent ID gating
    // ------------------------------------------------------------------------

    /// @notice True iff `account` holds at least one Agent ID (ERC721 balance > 0).
    function isAgentHolder(address account) public view returns (bool) {
        return IERC721Minimal(agentIdRegistry).balanceOf(account) > 0;
    }

    // ------------------------------------------------------------------------
    // Views — reports
    // ------------------------------------------------------------------------

    function reportsCount() external view returns (uint256) {
        return _reports.length;
    }

    function getReport(uint256 reportId) external view returns (Report memory) {
        if (reportId >= _reports.length) revert ReportNotFound();
        return _reports[reportId];
    }

    /// @notice All report ids filed about a given mint contract.
    function reportsByMint(address mintContract) external view returns (uint256[] memory) {
        return _reportsByMint[mintContract];
    }

    function hasReported(address reporter, address mintContract) external view returns (bool) {
        return _hasReported[reporter][mintContract];
    }

    function hasEndorsed(uint256 reportId, address endorser) external view returns (bool) {
        return _hasEndorsed[reportId][endorser];
    }

    // ------------------------------------------------------------------------
    // Writes — Agent ID holders only
    // ------------------------------------------------------------------------

    /// @notice File a safety report about a mint contract.
    /// @param mintContract The BSC contract of the mint being reported.
    /// @param name Human-readable project name.
    /// @param verdict 0 = Safe, 1 = Risky, 2 = Scam.
    /// @param evidenceURI Link to evidence (e.g. BscScan tx, audit, write-up).
    /// @return reportId The id of the newly created report.
    function submitReport(
        address mintContract,
        string calldata name,
        uint8 verdict,
        string calldata evidenceURI
    ) external onlyAgentHolder whenNotPaused returns (uint256 reportId) {
        if (mintContract == address(0)) revert ZeroAddress();
        if (bytes(name).length == 0) revert EmptyName();
        if (verdict > uint8(Verdict.Scam)) revert InvalidVerdict();
        if (_hasReported[msg.sender][mintContract]) revert AlreadyReported();

        reportId = _reports.length;
        _reports.push(
            Report({
                mintContract: mintContract,
                name: name,
                verdict: Verdict(verdict),
                evidenceURI: evidenceURI,
                reporter: msg.sender,
                createdAt: block.timestamp,
                endorsements: 0
            })
        );
        _reportsByMint[mintContract].push(reportId);
        _hasReported[msg.sender][mintContract] = true;

        emit ReportSubmitted(reportId, mintContract, msg.sender, Verdict(verdict));
    }

    /// @notice Endorse a report. One endorsement per Agent ID holder per report.
    ///         Reporters cannot endorse their own report.
    function endorse(uint256 reportId) external onlyAgentHolder whenNotPaused {
        if (reportId >= _reports.length) revert ReportNotFound();
        if (_reports[reportId].reporter == msg.sender) revert SelfEndorse();
        if (_hasEndorsed[reportId][msg.sender]) revert AlreadyEndorsed();

        _hasEndorsed[reportId][msg.sender] = true;
        _reports[reportId].endorsements += 1;

        emit Endorsed(reportId, msg.sender);
    }

    // ------------------------------------------------------------------------
    // Admin — pause only
    // ------------------------------------------------------------------------

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
