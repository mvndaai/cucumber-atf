# Dillify

Dillify shows your failing cucumber scenarios in order of most failing

Example output:

    | Failures | Step
    -------------------
    |      3   | math (.+) (.+) (.+)
    |      1   | run fail automatically step
    -------------------
    Total Failures: 4

## Installation

    $ gem install dillify

## Usage

Save output from cucumber

  $ cucumber --out ./log.txt

Use dillify on your log

  $ dillify ./log.txt

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
