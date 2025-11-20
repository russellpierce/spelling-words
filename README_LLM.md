# Spelling Words - Anki Deck Generator

A Python tool to automatically generate Anki flashcard decks for spelling test preparation. Creates cards with audio pronunciations and definitions from Merriam-Webster dictionaries.

## Features

- **Automatic Audio Downloads**: Fetches pronunciation audio from Merriam-Webster APIs
- **Definition Extraction**: Pulls age-appropriate definitions from Elementary Dictionary
- **Smart Caching**: Aggressive local caching reduces API calls and download times
- **Beautiful CLI**: Progress bars and colored output via Rich library
- **Zero Configuration**: Uses established libraries (genanki, requests-cache, click) instead of custom implementations

## Prerequisites

### System Requirements

- **Operating System**: Ubuntu 24.04 LTS (or compatible Linux)
- **Python**: 3.12+ (Ubuntu 24.04 default)
- **FFmpeg**: Required for audio processing

### Install FFmpeg

```bash
sudo apt-get update
sudo apt-get install -y ffmpeg
```

### Install uv (Python Package Manager)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd spelling-words
```

2. Install dependencies with uv:
```bash
uv sync
```

This will:
- Create a virtual environment
- Install all required packages:
  - `genanki` - Anki deck generation
  - `requests-cache` - HTTP caching
  - `pydantic-settings` - Configuration management
  - `click` - CLI framework
  - `rich` - Beautiful terminal output
  - `loguru` - Simplified logging
  - `pydub` - Audio processing
  - `requests` - HTTP client

## Configuration

### Get API Keys

1. Sign up for Merriam-Webster API keys:
   - **Elementary Dictionary** (primary): https://dictionaryapi.com/products/api-elementary-dictionary
   - **Collegiate Dictionary** (optional fallback): https://dictionaryapi.com/products/api-collegiate-dictionary

2. Create a `.env` file in the project root:
```bash
cp .env.example .env
```

3. Edit `.env` and add your API keys:
```env
MW_ELEMENTARY_API_KEY=your-actual-api-key-here
CACHE_DIR=.cache/
```

**Important**: Never commit your `.env` file to version control!

### API Rate Limits

- Merriam-Webster APIs have a limit of **1000 calls per day**
- This tool uses aggressive caching to minimize API usage
- Cached responses are stored for 30 days
- Re-running with the same word list uses cached data (no API calls)

## Usage

### Basic Usage

Create an Anki deck from a word list:

```bash
uv run python -m spelling_words --words my_words.txt --output spelling_deck.apkg
```

Or using short flags:

```bash
uv run python -m spelling_words -w my_words.txt -o spelling_deck.apkg
```

### Word List Format

Create a plain text file with one word per line:

```
apple
banana
elephant
dictionary
pronunciation
```

- Words should be lowercase
- Empty lines are ignored
- Duplicates are automatically removed
- Hyphens and apostrophes are allowed (e.g., "self-aware", "won't")

### Command-Line Options

```
Options:
  -w, --words PATH    Path to word list file [required]
  -o, --output PATH   Output APKG file path [default: output.apkg]
  -v, --verbose       Enable debug logging
  --help             Show this message and exit
```

### Verbose Mode

Enable detailed logging for debugging:

```bash
uv run python -m spelling_words -w words.txt -v
```

This shows:
- API requests and cache hits
- Audio download progress
- Processing details
- Any errors with full stack traces

## Output

### Generated APKG File

The tool creates an `.apkg` file that can be imported into:
- AnkiDroid (Android)
- Anki Desktop (Windows, Mac, Linux)
- AnkiWeb

### Card Structure

**Front (Question Side)**:
```
[Audio pronunciation]

Definition: <word definition from dictionary>
```

**Back (Answer Side)**:
```
word
```

Students hear the word and see its definition, then spell it. The answer shows the correct spelling.

## Caching

### Cache Location

By default, cached data is stored in `.cache/` (configurable via `.env`):

```
.cache/
└── spelling_words_cache.sqlite  # HTTP cache database
```

### Cache Behavior

- **API Responses**: Cached for 30 days
- **Audio Files**: Downloaded once, reused forever
- **Re-runs**: Nearly instant for previously processed words
- **Manual Clear**: Delete `.cache/` directory to start fresh

### Why Caching Matters

Processing 100 words without cache:
- 100+ API calls (10% of daily limit)
- 100+ audio downloads
- ~2-5 minutes

Processing same 100 words with cache:
- 0 API calls
- 0 downloads
- ~5-10 seconds

## Examples

### Example 1: Small Test

Create a test word list:

```bash
cat > test_words.txt << EOF
cat
dog
bird
fish
rabbit
EOF
```

Generate deck:

```bash
uv run python -m spelling_words -w test_words.txt -o test_deck.apkg
```

### Example 2: Weekly Spelling List

```bash
# Week 1
uv run python -m spelling_words -w week1_words.txt -o spelling_week1.apkg

# Week 2
uv run python -m spelling_words -w week2_words.txt -o spelling_week2.apkg
```

### Example 3: Large Vocabulary List

```bash
# Process 100+ words (uses cache for previously seen words)
uv run python -m spelling_words -w grade3_vocabulary.txt -o grade3.apkg -v
```

## Development

### Project Structure

```
spelling_words/
├── __init__.py          # Package initialization, loguru setup
├── __main__.py          # Entry point for python -m
├── cli.py               # Click CLI implementation
├── config.py            # Pydantic settings management
├── word_list.py         # Word list loading and validation
├── dictionary_client.py # Merriam-Webster API client
├── audio_processor.py   # Audio download and processing
└── apkg_manager.py      # genanki wrapper for APKG creation

tests/
├── fixtures/
│   └── test_words.txt   # Sample word list for testing
└── (test files)         # pytest test suite
```

### Running Tests

```bash
uv run pytest
```

With coverage:

```bash
uv run pytest --cov=spelling_words
```

### Code Style

This project follows the coding standards in `CLAUDE.md`:
- Only raise specific exception types
- Only catch known, resolvable exceptions
- Always log errors with stack traces (`loguru` handles this automatically)
- Use type hints for all function parameters
- Document all functions with docstrings

## Troubleshooting

### ffmpeg not found

```
Error: ffmpeg not found
```

Solution:
```bash
sudo apt-get install -y ffmpeg
```

### Missing API Key

```
Error: MW_ELEMENTARY_API_KEY environment variable not set
```

Solution: Create `.env` file with your API key (see Configuration section)

### Word Not Found

If a word isn't found in the Elementary Dictionary, it will be skipped with a warning. Check the logs to see which words were skipped.

Future versions will fall back to the Collegiate Dictionary.

### Import Error in Anki

If the APKG file won't import:
- Verify the file was created successfully
- Check file isn't corrupted (should be a ZIP file)
- Try with a smaller word list first
- Enable verbose mode to see detailed logs

### Cache Issues

If you suspect cache corruption:

```bash
# Clear cache
rm -rf .cache/

# Re-run
uv run python -m spelling_words -w words.txt -o output.apkg
```

## Technical Details

### Dependencies Explained

| Package | Purpose | Why We Use It |
|---------|---------|---------------|
| genanki | APKG generation | Industry standard, handles SQLite/ZIP complexity |
| requests-cache | HTTP caching | Transparent caching, multiple backends |
| pydantic-settings | Config management | Type-safe .env loading with validation |
| click | CLI framework | Decorator-based, excellent help generation |
| rich | Terminal output | Beautiful progress bars and colored text |
| loguru | Logging | Pre-configured, automatic exception logging |
| pydub | Audio processing | Simple API for audio format conversion |
| requests | HTTP client | De facto standard for HTTP in Python |

### Why Not Custom Implementations?

This project prioritizes using established, well-maintained libraries over custom code:

- **Less code to maintain**: ~300 lines instead of ~1500
- **Better tested**: Libraries have thousands of users finding bugs
- **More features**: Libraries evolve with new capabilities
- **Industry standard**: Same tools used by major Python projects

See `DESIGN.md` for detailed architectural decisions.

## Future Enhancements

See `DESIGN.md` for planned features:

- **Phase 2**: Multiple pronunciations with concatenation
- **Phase 3**: Update existing APKG files (add new words)
- **Phase 4**: Enhanced card content (IPA, etymology, usage examples)

## License

See LICENSE file for details.

## Contributing

See `DESIGN.md` and `CLAUDE.md` for development guidelines.
