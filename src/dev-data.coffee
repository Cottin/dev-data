path = require 'path'
fs = require 'fs'
util = require 'util'
express = require 'express'
bodyParser = require 'body-parser'
js2coffee = require 'js2coffee'
moment = require 'moment'
lo = require 'lodash'
{add, keys, map, replace, test} = R = require 'ramda' #auto_require:ramda

devDataServer = (devPath, port, dontTransactBeforeDelay = 3) ->
	app = new express()

	app.all '*', (req, res, next) ->
		res.set 'Access-Control-Allow-Origin', req.headers.origin
		res.set 'Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Content-Length, Accept, Origin'
		res.set 'Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, PATCH, DELETE'
		res.set 'Access-Control-Allow-Credentials', 'true'
		res.set 'Access-Control-Max-Age', 5184000
		next()

	app.use bodyParser.json()

	app.put '/dev/data/:name', (req, res) ->
		# debounce kommer inte fungera, man måste bygga upp en kö och ta saker i turordning
		# testa dock utan detta eftersom 16ms debounce i super-glue kanske räcker
		# putDebounced(req, res)
		put req, res

	put = (req, res) ->
		data = req.body
		if dontTransactBeforeDelay
			data.dontTransactBefore = moment().unix() + dontTransactBeforeDelay


		# add quotes to "weird" keys so js2coffee doesn't throw error
		replacer = (key, value) ->
			if value && R.is(Object, value) && ! R.is(Array, value)
				replacement = {}
				for k of value
					if ! test /^[a-zA-Z0-9_]*$/, k
						replacement['\'' + k + '\''] = value[k]
					else
						replacement[k] = value[k]
				return replacement
			return value

		json = JSON.stringify(req.body, replacer)
		console.log 'JSON', json
		json.replace /\\"/g, '￿'

		json = json.replace(/\"([^"]+)\":/g, '$1:')
								.replace(/\uFFFF/g, '\"')

		dataString = json
		dataStringJs = "var data = #{dataString};" 
		# console.log 'dataStringJs', dataStringJs
		dataStringCoffee = js2coffee.build(dataStringJs, {indent: '\t'}).code

		# bug in js2coffee: https://github.com/js2coffee/js2coffee/issues/362
		dataStringCoffee = dataStringCoffee.replace(/\\u9/g, '\t')

		dataStringCoffee += "\nmodule.exports = data"

		{name} = req.params
		filePath = devPath + "/#{name}.coffee"

		shouldOverwrite = req.query.shouldOverwrite || false
		if fs.existsSync(filePath) && !shouldOverwrite then return res.status(400).end()

		fs.writeFile filePath, dataStringCoffee, (err) ->
			if err then console.log err
			else res.status(200).end()

	# putDebounced = lo.debounce put, 100

	app.get '/dev/data', (req, res) ->
		console.log 'GET /dev/data'
		files = fs.readdirSync devPath
		extractNames = map(replace('.coffee', ''))
		res.send extractNames(files)

	app.get '/dev/data/:name', (req, res) ->
		{name} = req.params
		filePath = devPath + "/#{name}.coffee"
		if !fs.existsSync(filePath) then return res.status(404).end()

		dataFromFile = require filePath
		res.send dataFromFile

	app.listen port
	console.log "dev-data server listening on port #{port}"

module.exports = {devDataServer}
