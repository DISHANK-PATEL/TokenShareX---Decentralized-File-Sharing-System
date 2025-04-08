# TokenShareX — Decentralized File Sharing System

TokenShareX is a decentralized, incentive-driven file sharing system that leverages [IPFS](https://ipfs.io) for distributed file storage and ERC-20 tokens (ShareToken, SHT) as rewards for valuable contributions. This system empowers users to share useful resources (PDFs, JPEGs, PPTs, MP4s, etc.) while earning tokens for engaging in the network—all without relying on centralized servers.

## Table of Contents

- [Overview](#overview)
- [Core Idea](#core-idea)
- [Architecture](#architecture)
- [Flow Details](#flow-details)
  - [1. Setup (Initial Deployment)](#1-setup-initial-deployment)
  - [2. File Upload Flow](#2-file-upload-flow)
  - [3. Tipping Flow](#3-tipping-flow)
  - [4. Metadata Viewing Flow](#4-metadata-viewing-flow)
  - [5. Security & Validation Checks](#5-security--validation-checks)
- [Sequence & Use Case Diagrams](#sequence--use-case-diagrams)
- [Demo Screenshots](#demo-screenshots)
- [Installation and Setup](#installation-and-setup)
- [Testing with Remix IDE](#testing-with-remix-ide)
- [Future Enhancements](#future-enhancements)
- [License](#license)

## Overview

TokenShareX is designed to solve the problem of centralized file storage by utilizing IPFS to store files in a decentralized manner. Uploaders receive rewards in the form of SHT tokens when other users tip them for sharing valuable content. This creates a vibrant, censorship-resistant ecosystem that encourages collaboration and resource sharing.

## Core Idea

- **Decentralization**: Files are stored on IPFS using a content-addressable mechanism (CID generated from SHA-256) to ensure permanence and immutability.
- **Incentivized Sharing**: Users earn ERC-20 tokens (SHT) for contributing useful files.
- **Transparency and Auditability**: Metadata for each file (title, description, IPFS hash, uploader, tips received) is stored on-chain.
- **Self-Sustained Ecosystem**: Through peer-to-peer tipping, contributors are continuously rewarded, fostering a collaborative knowledge-sharing community.

## Architecture

### Components
- **Smart Contracts (Solidity)**
  - **ShareToken (SHT)**: ERC-20 token contract for platform rewards.
  - **TokenShareX Contract**: Stores on-chain metadata of uploaded files, handles the tipping mechanism, and serves as the core backend logic.
- **Storage (IPFS + Pinata)**
  - Files are uploaded externally using Pinata’s REST API.
  - IPFS returns a CID (e.g., `QmXyz...`), ensuring file integrity and immutability.
- **Frontend (Planned)**
  - A future React.js-based interface will be developed; for testing, interactions are performed via Remix IDE.

## Flow Details

### 1. Setup (Initial Deployment)

- **Deploy ERC-20 Token (ShareToken - SHT) Contract:**
  - This contract handles token minting and transfers.
  
- **Deploy the TokenShareX Smart Contract:**
  - Pass the deployed SHT token contract address.
  - Set an admin/owner address with minting permissions.

### 2. File Upload Flow

1. **File Selection & Upload:**
   - Users select a file from their local system.
   - The file is uploaded to IPFS using the Pinata API, which returns a CID (e.g., `QmXyz...`).

2. **Upload File Metadata to Smart Contract:**
   - The user copies the CID and calls the `uploadFile` function in the TokenShareX contract via Remix.
   - Function Parameters:
     - `title` (string)
     - `description` (string)
     - `ipfsHash` (string)
     - `timestamp` (using `block.timestamp` within the contract)

3. **On-Chain Processing:**
   - The contract verifies the sender.
   - It saves file metadata in a data structure:
     ```solidity
     struct FileMeta {
         string title;
         string description;
         string ipfsHash;
         uint256 timestamp;
         address uploader;
         uint256 tipsReceived;
     }
     ```
   - A `FileUploaded` event is emitted.

### 3. Tipping Flow

1. **User Interaction:**
   - Users browse the list of uploaded files via functions like `getAllFiles()` or `getFilesByUploader(address)`.
   - After selecting a file, the tipper calls the `tipUploader(uint fileId, uint amount)` function.

2. **Contract Actions:**
   - The contract checks that the tipper is not the uploader.
   - Transfers the specified `amount` of SHT tokens from the tipper to the uploader using `transferFrom`.
   - Updates the `tipsReceived` in the file's metadata.
   - Emits a `Tipped` event.

3. **Approval Requirement:**
   - Users need to authorize the TokenShareX contract to spend their tokens with:
     ```solidity
     SHT.approve(contractAddress, amount);
     ```

### 4. Metadata Viewing Flow

Users can retrieve on-chain metadata using the following functions:
- `getAllFiles()`: Returns metadata for all files.
- `getFilesByUploader(address uploader)`: Returns files uploaded by a specific address.
- `getFile(uint fileId)`: Returns metadata for a specific file.

### 5. Security & Validation Checks

- **Data Integrity:** IPFS CIDs are immutable, ensuring that files remain unchanged.
- **Self-Tipping Prevention:** The contract checks that uploaders cannot tip themselves.
- **Access Control:** Only the admin/owner can mint tokens, and file metadata, once stored, cannot be modified.
- **Event Logging:** All significant actions (file upload, tipping) emit events for transparency.

## Sequence & Use Case Diagrams

The following diagrams offer a high-level view of the system’s processes:

### Sequence Diagram
![Sequence Diagram](https://github.com/user-attachments/assets/4950c005-9dd2-44f2-9781-2336e4d63b9e)

### Use Case Diagram
![Use Case Diagram](https://github.com/user-attachments/assets/97242505-9184-4535-8f8d-aacc01995e4b)

## Demo Screenshots

Below are a few demo screenshots highlighting the system:
  
- ![Demo 1](https://github.com/user-attachments/assets/3c906a97-69a2-4310-b6a5-c76b65f93ba6)
- ![Demo 2](https://github.com/user-attachments/assets/741f9b8a-8ebf-44ba-bba7-95109c5b5351)![390137447-c814229b-827a-4797-806a-8a66a3339291](https://github.com/user-attachments/assets/2b1769e8-ab9c-4b9e-a400-28fc0ed0411c)
- ![Demo 3](https://github.com/user-attachments/assets/ac7feb56-699a-423e-9eaa-e9119df2a1cc) 


## Installation and Setup

### Cloning the Repository

To clone the repository locally, run:
```bash
git clone https://github.com/DISHANK-PATEL/TokenShareX---Decentralized-File-Sharing-System.git
cd TokenShareX---Decentralized-File-Sharing-System
