# Decentralized Public Mailbox and Postal Infrastructure Management

A comprehensive blockchain-based system for managing postal infrastructure using Clarity smart contracts on the Stacks blockchain.

## Overview

This system provides decentralized management of postal infrastructure through five interconnected smart contracts:

1. **Public Mailbox Maintenance Contract** - Coordinates repair, cleaning, and replacement of postal collection boxes
2. **Mail Slot Installation Oversight Contract** - Manages installation of mail slots in residential and commercial buildings
3. **Postal Route Optimization Contract** - Coordinates efficient mail delivery routes and carrier assignments
4. **Package Locker Management Contract** - Manages secure package delivery lockers in apartment complexes and businesses
5. **Mail Forwarding Coordination Contract** - Processes address changes and mail redirection services

## Features

### Public Mailbox Maintenance
- Track mailbox locations and conditions
- Schedule maintenance tasks
- Manage repair requests and completions
- Monitor mailbox capacity and usage

### Mail Slot Installation
- Register installation requests
- Track installation progress
- Manage contractor assignments
- Verify completion and quality

### Postal Route Optimization
- Define delivery routes
- Assign carriers to routes
- Track route efficiency metrics
- Optimize delivery schedules

### Package Locker Management
- Register locker locations
- Manage locker assignments
- Track package deliveries
- Handle access codes and security

### Mail Forwarding Coordination
- Process address change requests
- Manage forwarding periods
- Track forwarding status
- Handle forwarding fees

## Contract Architecture

Each contract operates independently while maintaining data integrity through standardized error codes and data structures.

### Data Types

- **Locations**: Standardized address format with coordinates
- **Status Tracking**: Consistent status enums across contracts
- **User Management**: Principal-based access control
- **Timing**: Block-height based scheduling

### Error Handling

Comprehensive error handling with descriptive error codes:
- Input validation errors (ERR-INVALID-INPUT)
- Authorization errors (ERR-NOT-AUTHORIZED)
- State errors (ERR-INVALID-STATE)
- Resource errors (ERR-NOT-FOUND)

## Getting Started

### Prerequisites

- Clarinet CLI
- Node.js and npm
- Stacks wallet for testing

### Installation

1. Clone the repository
2. Install dependencies: \`npm install\`
3. Run tests: \`npm test\`
4. Deploy contracts: \`clarinet deploy\`

### Testing

The system includes comprehensive tests using Vitest:

\`\`\`bash
npm test
\`\`\`

Tests cover:
- Contract deployment
- Function calls and state changes
- Error conditions
- Edge cases
- Integration scenarios

## Usage Examples

### Registering a Mailbox for Maintenance

\`\`\`clarity
(contract-call? .mailbox-maintenance register-mailbox
{street: "123 Main St", city: "Anytown", zip: u12345, lat: 4000000, lng: -7400000}
u100)
\`\`\`

### Requesting Mail Slot Installation

\`\`\`clarity
(contract-call? .mail-slot-installation request-installation
{street: "456 Oak Ave", city: "Somewhere", zip: u54321, lat: 4100000, lng: -7500000}
"residential")
\`\`\`

### Creating a Delivery Route

\`\`\`clarity
(contract-call? .postal-route-optimization create-route
"Downtown Route A"
[{street: "100 First St", city: "Downtown", zip: u10001, lat: 4050000, lng: -7450000}])
\`\`\`

## Security Considerations

- All contracts use principal-based authorization
- Input validation on all public functions
- State consistency checks
- No cross-contract dependencies to minimize attack surface

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details
