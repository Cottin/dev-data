{devDataServer} = require './dev-data'

# start dev-data server
devDataServer(__dirname, 3707, 6)


# Run with this:
# coffee test.coffee
# curl -X PUT -H "Content-Type: application/json" --data '{"email":"anna@ab.se", "3903e13d353f311d48a76d1b3591ff53251a7211":"123"}' -s -D - http://localhost:3707/dev/data/output_from_test\?shouldOverwrite\=true
