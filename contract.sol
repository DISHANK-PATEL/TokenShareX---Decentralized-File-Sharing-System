// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ShareToken
 * @dev ERC20 token used for rewarding uploaders in the RewardFileSharing system.
 *
 * Features:
 *  - Standard ERC20 with mint capability (onlyOwner).
 *  - The token is used to tip uploaders and as reward currency.
 *
 * Note: This contract uses OpenZeppelin’s ERC20 and Ownable libraries.
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ShareToken is ERC20, Ownable {
    /**
     * @dev Constructor that gives msg.sender an initial supply of tokens.
     */
    constructor() ERC20("ShareToken", "SHT") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    /**
     * @notice Mint tokens to a specified address.
     * @param to The recipient of the newly minted tokens.
     * @param amount The number of tokens to be minted (in smallest unit).
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

/**
 * @title RewardFileSharing
 * @dev This contract manages a decentralized file sharing system that rewards uploaders
 *      with ERC20 tokens when users tip for files stored by IPFS. It supports operations
 *      like file uploads, file metadata updates, tipping, and retrieval of file data.
 *
 * Key Features:
 *  - Each file is stored with an IPFS hash, title, description, category, tags, and ratings.
 *  - Users can tip uploaders using the ShareToken (ERC20).
 *  - Uploaders may update their file information.
 *  - Users can add ratings and comments for shared files.
 *  - The contract tracks total tips per file and per uploader.
 *
 * Additional interfaces and functions are provided to expand the system.
 */
contract RewardFileSharing is Ownable {
    using Counters for Counters.Counter;

    /// @dev Instance of the ERC20 token used for rewards.
    ShareToken public token;

    /// @dev Constructor setting the token address.
    constructor(address _token) {
        token = ShareToken(_token);
    }

    // ----------------------------------
    // Structures and Enumerations
    // ----------------------------------

    /**
     * @notice File metadata and reward details.
     */
    struct File {
        uint256 id;                  // Unique file ID.
        string ipfsHash;             // IPFS content identifier.
        string title;                // File title.
        string description;          // Detailed file description.
        string category;             // Category for file classification.
        string[] tags;               // Array of tags associated with the file.
        address uploader;            // Address that uploaded the file.
        uint256 uploadTimestamp;     // Timestamp of file upload.
        uint256 totalTips;           // Total ERC20 token tips received.
        uint256 averageRating;       // Average rating (in basis points, e.g., out of 10000).
        uint256 ratingCount;         // Number of ratings received.
    }

    /**
     * @notice Structure to hold individual file comments.
     */
    struct Comment {
        uint256 fileId;              // File the comment pertains to.
        address commenter;           // Commenter's address.
        string content;              // Comment text.
        uint256 timestamp;           // When the comment was submitted.
    }

    // ----------------------------------
    // Counters, Mappings, and State Variables
    // ----------------------------------

    /// @dev Counter for file IDs.
    Counters.Counter private _fileIdCounter;

    /// @dev Mapping from file ID to file metadata.
    mapping(uint256 => File) public files;

    /// @dev Mapping from uploader address to list of file IDs uploaded.
    mapping(address => uint256[]) public uploaderFiles;

    /// @dev Mapping from file ID to an array of comments.
    mapping(uint256 => Comment[]) public fileComments;

    // ----------------------------------
    // Events
    // ----------------------------------

    event FileUploaded(
        uint256 indexed fileId,
        address indexed uploader,
        string ipfsHash,
        string title
    );

    event FileUpdated(
        uint256 indexed fileId,
        string newTitle,
        string newDescription,
        string newCategory
    );

    event FileTagged(
        uint256 indexed fileId,
        string tag
    );

    event FileTipped(
        uint256 indexed fileId,
        address indexed tipper,
        uint256 amount
    );

    event FileRated(
        uint256 indexed fileId,
        address indexed rater,
        uint256 rating,
        uint256 newAverage,
        uint256 ratingCount
    );

    event CommentAdded(
        uint256 indexed fileId,
        address indexed commenter,
        string content
    );

    // ----------------------------------
    // Modifiers
    // ----------------------------------

    /**
     * @notice Checks that the file exists.
     */
    modifier fileExists(uint256 fileId) {
        require(files[fileId].id != 0, "File does not exist");
        _;
    }

    /**
     * @notice Restricts function usage to the uploader of the file.
     */
    modifier onlyUploader(uint256 fileId) {
        require(files[fileId].uploader == msg.sender, "Caller is not the uploader");
        _;
    }

    // ----------------------------------
    // File Uploading and Updating Functions
    // ----------------------------------

    /**
     * @notice Upload a new file to the platform.
     * @param ipfsHash The IPFS CID for the file content.
     * @param title The title for the file.
     * @param description A detailed description of the file.
     * @param category The category for the file.
     * @param tags An array of tags associated with the file.
     */
    function uploadFile(
        string calldata ipfsHash,
        string calldata title,
        string calldata description,
        string calldata category,
        string[] calldata tags
    ) external {
        require(bytes(ipfsHash).length > 10, "Invalid IPFS hash");
        require(bytes(title).length > 0, "Title is required");
        // Increment file counter and assign ID.
        _fileIdCounter.increment();
        uint256 fileId = _fileIdCounter.current();
        
        // Create File structure.
        File storage newFile = files[fileId];
        newFile.id = fileId;
        newFile.ipfsHash = ipfsHash;
        newFile.title = title;
        newFile.description = description;
        newFile.category = category;
        newFile.uploader = msg.sender;
        newFile.uploadTimestamp = block.timestamp;
        newFile.totalTips = 0;
        newFile.averageRating = 0;
        newFile.ratingCount = 0;
        
        // Add tags to the file structure.
        for (uint256 i = 0; i < tags.length; i++) {
            newFile.tags.push(tags[i]);
            emit FileTagged(fileId, tags[i]);
        }
        
        // Record file under uploader.
        uploaderFiles[msg.sender].push(fileId);
        
        emit FileUploaded(fileId, msg.sender, ipfsHash, title);
    }

    /**
     * @notice Update file metadata (title, description, category).
     * @param fileId The ID of the file to update.
     * @param newTitle The new title.
     * @param newDescription The new description.
     * @param newCategory The new category.
     */
    function updateFileMetadata(
        uint256 fileId,
        string calldata newTitle,
        string calldata newDescription,
        string calldata newCategory
    ) external fileExists(fileId) onlyUploader(fileId) {
        File storage fileToUpdate = files[fileId];
        fileToUpdate.title = newTitle;
        fileToUpdate.description = newDescription;
        fileToUpdate.category = newCategory;
        
        emit FileUpdated(fileId, newTitle, newDescription, newCategory);
    }

    // ----------------------------------
    // File Rating Functions
    // ----------------------------------

    /**
     * @notice Rate a file.
     * @param fileId The file ID to rate.
     * @param rating The rating value (1-10000, where 10000 equals a 5-star rating if scaled appropriately).
     */
    function rateFile(uint256 fileId, uint256 rating) external fileExists(fileId) {
        require(rating > 0 && rating <= 10000, "Rating must be between 1 and 10000");
        
        File storage fileToRate = files[fileId];
        uint256 totalRating = fileToRate.averageRating * fileToRate.ratingCount;
        
        // Update rating count and average using new value.
        fileToRate.ratingCount += 1;
        totalRating += rating;
        fileToRate.averageRating = totalRating / fileToRate.ratingCount;
        
        emit FileRated(fileId, msg.sender, rating, fileToRate.averageRating, fileToRate.ratingCount);
    }

    // ----------------------------------
    // Commenting Functions
    // ----------------------------------

    /**
     * @notice Add a comment to a file.
     * @param fileId The file ID to comment on.
     * @param content The content of the comment.
     */
    function addComment(uint256 fileId, string calldata content) external fileExists(fileId) {
        require(bytes(content).length > 0, "Comment cannot be empty");
        Comment memory newComment = Comment({
            fileId: fileId,
            commenter: msg.sender,
            content: content,
            timestamp: block.timestamp
        });
        fileComments[fileId].push(newComment);
        emit CommentAdded(fileId, msg.sender, content);
    }

    // ----------------------------------
    // Tipping Functionality
    // ----------------------------------

    /**
     * @notice Tip a file uploader using ShareToken.
     * @param fileId The ID of the file to tip.
     * @param amount The amount of tokens to send as tip.
     */
    function tipFile(uint256 fileId, uint256 amount) external fileExists(fileId) {
        File storage file = files[fileId];
        require(file.uploader != msg.sender, "Uploader cannot tip own file");
        require(amount > 0, "Tip amount must be positive");
        
        // Transfer tokens from tipper to uploader.
        bool success = token.transferFrom(msg.sender, file.uploader, amount);
        require(success, "Token transfer failed");
        
        file.totalTips += amount;
        emit FileTipped(fileId, msg.sender, amount);
    }

    // ----------------------------------
    // Retrieval Functions
    // ----------------------------------

    /**
     * @notice Get full details of a file by its ID.
     * @param fileId The file ID to retrieve.
     * @return File metadata including IPFS hash, title, description, and ratings.
     */
    function getFile(uint256 fileId) external view fileExists(fileId) returns (File memory) {
        return files[fileId];
    }

    /**
     * @notice Retrieve all file IDs uploaded by a specific user.
     * @param uploader The address of the uploader.
     * @return Array of file IDs.
     */
    function getFilesByUploader(address uploader) external view returns (uint256[] memory) {
        return uploaderFiles[uploader];
    }

    /**
     * @notice Get all files in the system.
     * @return Array of all files.
     */
    function getAllFiles() external view returns (File[] memory) {
        uint256 totalFiles = _fileIdCounter.current();
        File[] memory allFiles = new File[](totalFiles);
        for (uint256 i = 1; i <= totalFiles; i++) {
            allFiles[i - 1] = files[i];
        }
        return allFiles;
    }

    /**
     * @notice Get comments associated with a file.
     * @param fileId The file ID.
     * @return Array of comments for that file.
     */
    function getComments(uint256 fileId) external view fileExists(fileId) returns (Comment[] memory) {
        return fileComments[fileId];
    }

    // ----------------------------------
    // Administrative Functions
    // ----------------------------------

    /**
     * @notice Update the token contract address (for upgrades).
     * @param newToken The address of the new ShareToken.
     */
    function updateTokenAddress(address newToken) external onlyOwner {
        token = ShareToken(newToken);
    }

    /**
     * @notice Withdraw tokens from this contract.
     * @param to The recipient address.
     * @param amount The amount of tokens to withdraw.
     */
    function withdrawTokens(address to, uint256 amount) external onlyOwner {
        require(amount > 0, \"Amount must be positive\");
        bool success = token.transfer(to, amount);
        require(success, \"Withdrawal failed\");
    }

    // ----------------------------------
    // Reward Distribution (Optional Extension)
    // ----------------------------------

    /**
     * @notice Mapping to track pending reward balances for uploaders.
     */
    mapping(address => uint256) public pendingRewards;

    event RewardClaimed(address indexed uploader, uint256 amount);

    /**
     * @notice Accrue rewards to the uploader when their file gets tipped.
     *         This internal function can be expanded to include bonus logic.\n
     * @param uploader The uploader address.
     * @param amount The tip amount which is added as reward.
     */
    function _accrueReward(address uploader, uint256 amount) internal {
        pendingRewards[uploader] += amount;
    }

    /**
     * @notice Claim accrued rewards from tips.
     */
    function claimReward() external {
        uint256 reward = pendingRewards[msg.sender];
        require(reward > 0, \"No rewards to claim\");
        pendingRewards[msg.sender] = 0;
        bool success = token.transfer(msg.sender, reward);
        require(success, \"Reward transfer failed\");
        emit RewardClaimed(msg.sender, reward);
    }

    // ----------------------------------
    // Fallback and Receive Functions
    // ----------------------------------

    /**
     * @notice Fallback function to accept ETH (if needed for future upgrades).\n
     * Note: This contract primarily deals with ERC20, but it can receive ETH to support ancillary functions.\n
     */
    fallback() external payable {
        // Accept ETH and log if needed.
    }

    receive() external payable {
        // Accept ETH directly.
    }

    // ----------------------------------
    // Interface Declarations (for future extensibility)
    // ----------------------------------

    /**
     * @notice Interface for a module to handle file pinning on IPFS.
     */
    interface IFilePinning {
        function pinFile(string calldata ipfsHash) external returns (bool);
        function unpinFile(string calldata ipfsHash) external returns (bool);
    }

    /**
     * @notice Interface for a module that provides analytics on file sharing metrics.
     */
    interface IAnalytics {
        function recordUpload(address uploader, uint256 fileId) external;
        function recordTip(address tipper, uint256 fileId, uint256 amount) external;
        function recordRating(uint256 fileId, uint256 rating) external;
    }

    // ----------------------------------
    // Utility Functions
    // ----------------------------------

    /**
     * @notice Helper function to get a file's details as a formatted string.
     * @dev Not meant for production (expensive in terms of gas) but useful for debugging off-chain.
     * @param fileId The file ID.
     * @return A concatenated string with file information.
     */
    function getFileDetailsString(uint256 fileId) external view fileExists(fileId) returns (string memory) {
        File memory file = files[fileId];
        // Concatenate various file attributes; note this is not efficient for on-chain usage.
        return string(abi.encodePacked(
            \"ID: \", uint2str(file.id), \"; \",
            \"Title: \", file.title, \"; \",
            \"IPFS Hash: \", file.ipfsHash, \"; \",
            \"Uploader: \", toAsciiString(file.uploader), \"; \",
            \"Tips: \", uint2str(file.totalTips)
        ));
    }

    // ----------------------------------
    // Internal Utility Functions
    // ----------------------------------

    /**
     * @dev Converts a uint to a string.
     */
    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return \"0\";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        j = _i;
        while (j != 0) {
            k = k - 1;
            uint8 temp = uint8(48 + j % 10);
            bstr[k] = bytes1(temp);
            j /= 10;
        }
        return string(bstr);
    }

    /**
     * @dev Converts an address to its ASCII string representation.
     */
    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    /**
     * @dev Helper function: converts a byte to its ASCII character.
     */
    function char(bytes1 b) internal pure returns (bytes1 c) {
        uint8 ub = uint8(b);
        if (ub < 10) {
            return bytes1(ub + 48);
        }
        return bytes1(ub + 87);
    }
}

// End of Reward-Based File Sharing System contracts
