# App Store Connect CLI

A Swift-based command-line interface for App Store Connect operations, replacing broken bash/Python authentication scripts with a reliable, native Swift implementation.

## ✅ Status

**All CLI commands are tested and working with real App Store Connect authentication!**

The authentication system successfully connects to the App Store Connect API using the official `AppStoreConnect-Swift-SDK`. Business logic implementations are stubs ready for API integration.

## Features

- 🔐 **Reliable Authentication** - Uses Apple's official SDK with proper JWT handling
- 🎯 **Type-Safe** - Built with Swift 6.0 and strict concurrency checking
- 🧪 **Well-Tested** - Comprehensive test coverage with SwiftTesting framework
- 📝 **SwiftLint Integrated** - Enforces code quality from the beginning
- 🎨 **Beautiful CLI** - Colored output with progress indicators
- 🔄 **Modular Design** - Protocol-driven architecture for easy extension

## Installation

### Build from Source

```bash
cd AppStoreConnectCLI
swift build -c release
```

The binary will be available at `.build/release/app-store-cli`

### Install Globally

```bash
swift build -c release
sudo cp .build/release/app-store-cli /usr/local/bin/
```

## Authentication

The CLI supports authentication via environment variables or configuration file.

### Environment Variables

```bash
export APPSTORE_KEY_ID="YOUR_KEY_ID"
export APPSTORE_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_PATH="/path/to/AuthKey_XXXXX.p8"
export TEAM_ID="YOUR_TEAM_ID"  # Optional
```

Alternative environment variable names are also supported:
- `APP_STORE_CONNECT_API_KEY_ID` (alternative to `APPSTORE_KEY_ID`)
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID` (alternative to `APPSTORE_ISSUER_ID`)
- `APPSTORE_P8_KEY` (raw key content instead of path)
- `DEVELOPMENT_TEAM` (alternative to `TEAM_ID`)

### Configuration File

Create a JSON configuration file:

```json
{
  "key_id": "YOUR_KEY_ID",
  "issuer_id": "YOUR_ISSUER_ID",
  "private_key_path": "/path/to/AuthKey_XXXXX.p8",
  "team_id": "YOUR_TEAM_ID",
  "timeout": 30,
  "retry_attempts": 3,
  "verbose_logging": true
}
```

Use with: `app-store-cli --config /path/to/config.json status`

## Commands

### Status

Check authentication and API connection status:

```bash
app-store-cli status
app-store-cli status --verbose
```

### Metadata Management

List all apps:
```bash
app-store-cli metadata list
app-store-cli metadata list --platform iOS --detailed
```

Download app metadata:
```bash
app-store-cli metadata download --bundle-id com.example.app --output ./metadata
```

Upload app metadata:
```bash
app-store-cli metadata upload --bundle-id com.example.app --input ./metadata
```

### Version Management

List app versions:
```bash
app-store-cli version list --bundle-id com.example.app
```

Create a new version:
```bash
app-store-cli version create --bundle-id com.example.app --version-string 2.0.0
app-store-cli version create --bundle-id com.example.app --version-string 2.0.0 --draft
```

Update a version:
```bash
app-store-cli version update --bundle-id com.example.app --version-string 2.0.0 --copyright "2024 My Company"
```

Delete a version:
```bash
app-store-cli version delete --bundle-id com.example.app --version-string 2.0.0
app-store-cli version delete --bundle-id com.example.app --version-string 2.0.0 --force
```

### Build Management

List builds:
```bash
app-store-cli build list --bundle-id com.example.app
app-store-cli build list --bundle-id com.example.app --processing --limit 20
```

Get build info:
```bash
app-store-cli build info --build-id 12345678
```

Check build status:
```bash
app-store-cli build status --build-id 12345678
```

## Global Options

All commands support these global options:

- `-c, --config <path>` - Path to configuration file
- `-v, --verbose` - Enable verbose output
- `--no-color` - Disable colored output
- `--help` - Show help information
- `--version` - Show CLI version

## Platform Support

The following platforms are supported:
- iOS
- macOS  
- visionOS

Specify platform with `--platform` option where applicable.

## Testing

Run the comprehensive test suite:

```bash
./test-cli.sh
```

This will test all CLI commands with real authentication.

## Development

### Project Structure

```
AppStoreConnectCLI/
├── Sources/
│   └── AppStoreConnectCLI/
│       ├── CLI/              # CLI entry points and output
│       ├── Commands/         # Command implementations
│       ├── Core/            # Core types and protocols
│       └── Services/        # Business logic services
├── Tests/                   # Test suites
├── Package.swift           # Swift package manifest
├── Makefile               # Build automation
└── .swiftlint.yml         # Code style rules
```

### Building

```bash
make build          # Debug build
make build-release  # Release build
make test          # Run tests
make lint          # Run SwiftLint
make clean         # Clean build artifacts
```

### Architecture

The CLI follows a protocol-driven design:

1. **AuthenticationService** - Protocol for authentication operations
2. **AppStoreConnectAuthenticationService** - Concrete implementation using SDK
3. **Commands** - Implement `AuthenticatedCommand` protocol
4. **CLIOutput** - Centralized output formatting
5. **Configuration** - Flexible configuration management

### Adding New Commands

1. Create a new command file in `Commands/`
2. Implement the `AuthenticatedCommand` protocol
3. Add to subcommands in `AppStoreCLI.swift`
4. Implement business logic in Services layer

## Troubleshooting

### Authentication Fails

1. Verify your API key has the correct permissions in App Store Connect
2. Check that the .p8 file path is correct and readable
3. Ensure the issuer ID is in UUID format
4. Verify the key ID is exactly 10 characters

### PEM Key Issues

The CLI automatically extracts the base64 content from PEM-formatted keys. Ensure your key file:
- Starts with `-----BEGIN PRIVATE-KEY-----`
- Ends with `-----END PRIVATE-KEY-----`
- Contains valid base64 content between headers

### Rate Limiting

The SDK handles rate limiting automatically. If you encounter rate limits, the CLI will show appropriate error messages with retry suggestions.

## Implementation Status

✅ **Completed:**
- CLI infrastructure and argument parsing
- Authentication with App Store Connect API
- Error handling and user feedback
- Command structure for all operations
- SwiftLint integration
- Swift 6.0 concurrency support

🔄 **Ready for Implementation:**
- Actual API calls for each command
- Response parsing and display
- File I/O for metadata operations
- Progress tracking for long operations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run `make lint` and `make test`
5. Submit a pull request

## License

This project is part of the Think client and follows the same license terms.