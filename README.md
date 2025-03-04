# Perplexity API Terminal Client

A command-line tool for searching and exporting information using the Perplexity AI API.

**Version:** 1.0.0  
**Last Updated:** 2025-03-04  
**Maintained by:** Jack5316

## Features

- Search for information using Perplexity AI directly from your terminal
- Support for all Perplexity AI models (sonar, sonar-pro, etc.)
- Export search results to various formats (Markdown, Text, PDF)
- Debug mode for troubleshooting
- Raw response viewing for development
- Secure API key management and verification

## Installation

1. Download the script:

   ```bash
   curl -O https://raw.githubusercontent.com/username/repo/main/pplx_search.sh
   ```

2. Make it executable:

   ```bash
   chmod +x pplx_search.sh
   ```

3. (Optional) Move to your PATH for system-wide access:

   ```bash
   sudo mv pplx_search.sh /usr/local/bin/pplx
   ```

## Dependencies

- `curl` - Required for API communication
- `jq` - Recommended for better JSON parsing and formatted output
- For PDF export (one of the following):
  - `pandoc` (recommended)
  - `wkhtmltopdf`
  - `enscript` + `ps2pdf`

## Configuration

Run the configuration command to set up your API key:

```bash
pplx configure
```

Your API key will be stored in `~/.pplx_search.conf` with secure permissions (600).

## Usage

### Basic commands

```bash
# Search for information
pplx search "your search query"

# Search using a specific model
pplx search -m sonar-pro "your search query"

# View available models
pplx models

# Verify API key
pplx verify

# Get help
pplx help
```

### Exporting Results

```bash
# Export to Markdown (default)
pplx export "your search query"

# Export as text file
pplx export -f txt "your search query"

# Export as PDF
pplx export -f pdf "your search query"

# Specify output filename
pplx export -o filename.md "your search query"

# Combine options
pplx export -f pdf -o research.pdf -m sonar-pro "detailed search query"
```

### Advanced Usage

```bash
# Debug mode (verbose output)
pplx debug "your search query"

# View raw API response
pplx raw "your search query"
```

## Export Formats

- **Markdown (.md)** - Default format with structured sections
- **Text (.txt)** - Plain text format with simple formatting
- **PDF (.pdf)** - PDF document (requires additional tools)

## Supported Models

Run `pplx models` for the complete and up-to-date list. Current models include:

- sonar (default)
- sonar-pro
- sonar-deep-research
- sonar-reasoning
- sonar-reasoning-pro
- r1-1776

## Troubleshooting

### PDF Export Issues

Install one of the supported PDF conversion tools:

```bash
# Install pandoc (recommended)
sudo apt install pandoc  # Debian/Ubuntu
brew install pandoc      # macOS

# Or wkhtmltopdf
sudo apt install wkhtmltopdf  # Debian/Ubuntu
brew install wkhtmltopdf      # macOS
```

### API Authentication Errors

If you receive "401 Authorization Required" errors:

1. Verify your API key with `pplx verify`
2. Ensure your subscription is active
3. Run `pplx configure` to update your key

### Improved Output Formatting

Install `jq` for better formatting and to see sources:

```bash
sudo apt install jq  # Debian/Ubuntu
brew install jq      # macOS
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Perplexity AI](https://www.perplexity.ai) for providing the API
- Contributors and testers who helped improve this tool

---

*Documentation generated on 2025-03-04 15:25:42 UTC*
