# GUT Configuration File
# See: https://github.com/bitwes/Gut/wiki/gut_config.gf

[gd_resource]
script/subcategory = "GutConfig"

[gut]

# Directory containing test scripts
directory = 'res://tests'

# File patterns for test scripts
file_pattern = 'test_*.gd'

# Include subdirectories
include_subdirectories = true

# Run tests in this order
unit_test_name_prefix = 'test_'

# Should we double check orphan nodes?
check_orphans_before_test = true

# Log level (0-3, higher = more verbose)
log_level = 2

# Paint after each test (useful for visual debugging)
paint_after = 0.1

# Disable strict type checking for autofree
should_maximize = false

# Output format (terminal, vs_code)
output_format = 'terminal'

# Show the gut panel in the editor
hide_orphans = false

[import]

# Import settings
import = false
