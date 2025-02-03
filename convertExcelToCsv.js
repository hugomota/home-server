const fs = require('fs')
const path = require('path')
const xlsx = require('xlsx')

// Function to convert a single Excel file to CSV
const convertToCSV = (filePath) => {
  const workbook = xlsx.readFile(filePath)
  workbook.SheetNames.forEach((sheetName) => {
    const worksheet = workbook.Sheets[sheetName]
    const csvData = xlsx.utils.sheet_to_csv(worksheet)
    const outputFilePath = path.join(
      path.dirname(filePath),
      `${path.basename(filePath, path.extname(filePath))}-${sheetName}.csv`
    )
    fs.writeFileSync(outputFilePath, csvData, 'utf8')
    console.log(`Converted: ${filePath} to ${outputFilePath}`)
  })
}

// Main function to iterate through all Excel files in a directory
const convertAllExcelInFolder = (folderPath) => {
  fs.readdir(folderPath, (err, files) => {
    if (err) {
      console.error(`Error reading folder: ${err}`)
      return
    }

    files.forEach((file) => {
      const filePath = path.join(folderPath, file)
      const ext = path.extname(file).toLowerCase()
      if (ext === '.xlsx' || ext === '.xls') {
        try {
          convertToCSV(filePath)
        } catch (error) {
          console.error(`Error converting file ${filePath}: ${error}`)
        }
      }
    })
  })
}

const folderPath = './excel_files' // Replace with your folder path
convertAllExcelInFolder(folderPath)
