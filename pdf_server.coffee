BUCKET_NAME = 'andrewjohnsonmt'

express = require 'express'
bodyParser = require 'body-parser'
moment = require 'moment'
fs = require 'fs'

request = require 'request'

http = require 'http'
path = require 'path'
aws = require 'aws-sdk'
aws.config.loadFromPath('./AwsConfig.json')

s3 = new aws.S3()
#mtURL = "localhost"
#mtPort = "8080"

mtURL = "http://demo.maketime.io/"
mtPort = "8080"

PDFDocument = require 'pdfkit'
pdfID = ""
pdfName = "pdf_test"
pdfUrl = ""

app = express()
jsonParser = bodyParser.json()

app.use( (req,res,next) ->
	res.header("Access-Control-Allow-Origin", "*")
	res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept")
	next()
	)

app.get('/', (req, res, next) ->
		res.send('Got a GET request')
	)

app.post('/grommet', jsonParser, (req, res, next) ->
		res.send('Got a POST request')
		if (!req.body) 
			return res.sendStatus(400)
		else
			console.log(req.body["pdfObj"])
			pdfID = moment().valueOf();
			pdfUrl = "http://s3.amazonaws.com/" + BUCKET_NAME + "/" + pdfName + pdfID + ".pdf"
			console.log(pdfUrl)
			grommetPdfGenerator(req.body)
	)

app.put('/', (req, res, next) ->
		res.send('Got a PUT request')
	)

app.delete('/', (req, res, next) ->
		res.send('Got a DELETE request')
	)

server = app.listen(4000, () ->
		host = server.address().address
		port = server.address().port

		console.log('Example app listening at http://%s:%s', host, port)
	)

sendToMaketime = (req) ->
	post_data = {
		hours:req["hours"],
		machine_type:req["machine_type"],
		material:req["material"],
		needed_by_date:req["needed_by_date"],
		notes_to_seller:req["notes_to_seller"],
		assets:[pdfUrl]
	}
	dataString = JSON.stringify(post_data)
	headers = {
		'Content-Type': 'application/json'
	}
	options = {
		host: mtURL,
		path: '/public_api/v1/time_requests?api_token=buyer_api_token',
		port: mtPort,
		method: 'POST',
		headers: headers
	}
	req = http.request(options, (res) ->
		res.setEncoding('utf-8')
		responseString = ''

		res.on('data', (data) ->
			responseString += data
			)
		res.on('end', () ->
			resultObject = JSON.parse(responseString)
		)
	)
	req.on('error', (e) ->
			#TODO: HANDLE ERRORS
			console.log(e)
			console.log("Error on sendToMaketime")
		)
	req.on('data', (data) -> 
		console.log(data.toString())
		)
	req.on('end', () ->
		console.log("This is the end...")
		)
	req.write(dataString)
	req.end()


grommetPdfGenerator = (requestBody) -> 
	innerRadius = requestBody.pdfObj["innerRadius"]
	outerRadius = requestBody.pdfObj["outerRadius"]
	doc = new PDFDocument
	writeStream = fs.createWriteStream(pdfName + pdfID + '.pdf')
	doc.pipe writeStream
	doc.info["Title"] = "DynamicGrommetPDF" + moment()
	doc.info["Author"] = "MakeTime Grommet Factory"
	doc.info["Subject"] = "Grommet Schematic"
	doc.page.margin = 0;
	centerY = 300 #(doc.page.width/2) - (outerRadius*2)
	centerX = 300 #(doc.page.height/2) - (outerRadius*2)
	doc.text('outerCircleRadius = ' + outerRadius + "mm", 100, 80)
	   .moveDown()
	   .text('innerCircleRadius = ' + innerRadius + "mm")
	console.log("Grommet has outerRadius of " + outerRadius + " and innerRadius of " + innerRadius)
	doc.circle(centerX,centerY,outerRadius)
	   .circle(centerX,centerY,innerRadius)
	   .fill('even-odd')
	doc.end()
	writeStream.on('finish', () -> 
		uploadFile(pdfName + pdfID + '.pdf', pdfName + pdfID + '.pdf', requestBody)
		innerRadius = ""
		outerRadius = ""
		writeStream = ""
		)

uploadFile = (remoteFilename, fileName, requestBody) ->
	fileBuffer = fs.readFileSync(fileName)
	metaData = getContentTypeByFile(fileName)

	s3.putObject({
		ACL: 'public-read',
		Bucket: BUCKET_NAME,
		Key: remoteFilename,
		Body: fileBuffer,
		ContentType: metaData
		}, (error, response) ->
			if error
				console.log(error)
				console.log("UploadFile Error")
			else
				console.log('uploaded file[' + fileName + '] to [' + remoteFilename + '] as [' + metaData + ']')
				console.log(arguments)
				sendToMaketime(requestBody)
		)


getContentTypeByFile = (fileName) ->
	rc = 'application/octet-stream'
	fileNameLowerCase = fileName.toLowerCase()

	if (fileNameLowerCase.indexOf('.pdf') >= 0) 
		rc = 'application/pdf'
	else 
		console.log("File is not pdf")
		return
	return rc

