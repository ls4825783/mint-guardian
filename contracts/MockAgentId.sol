// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title MockAgentId — minimal ERC721 used ONLY on BSC testnet (chain 97)
/// @notice The real Agent ID registry (0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F)
///         exists only on BSC mainnet. This mock lets the same MintGuardian
///         bytecode be tested on testnet with the identical gating code path
///         (balanceOf > 0). NEVER deploy this mock on mainnet and NEVER point
///         a mainnet MintGuardian at it.
contract MockAgentId {
    string public constant name = "Mock Agent ID";
    string public constant symbol = "MAID";
    uint256 private _nextTokenId = 1;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "zero address");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "nonexistent token");
        return owner;
    }

    /// @notice Mint a test Agent ID to `to`. Anyone may call on testnet.
    function mintTestId(address to) external returns (uint256 tokenId) {
        require(to != address(0), "zero address");
        tokenId = _nextTokenId++;
        _owners[tokenId] = to;
        _balances[to] += 1;
        emit Transfer(address(0), to, tokenId);
    }
}
