const process = require('process')
const child_process = require('child_process')
const readline = require('readline')
const https = require('https')
const fs = require('fs')

/**
 * @param {string} str
 */
function printYellow(str) {
  console.log(`\x1b[33m${str}\x1b[0m`)
}

/**
 * @param {string} str
 */
function printBlue(str) {
  console.log(`\x1b[36m${str}\x1b[0m`)
}

/**
 * @param {string[]} lineArray
 * @param {(result:string)=>{}} done
 */
function chooseLine(lineArray, done) {
  readline.emitKeypressEvents(process.stdin)
  process.stdin.setRawMode(true)

  let currentIndex = 0
  let printLine = () => {
    lineArray.forEach((element, index) => {
      if (index == currentIndex) {
        printBlue('❯ ' + element)
      } else {
        console.log('  ' + element)
      }
    });
  }
  printLine()

  let keypresshandle = (str, key) => {
    if (key.sequence === '\u0003') {
      process.exit()
    }
    if (key.code === '[A') {
      currentIndex--
    } else if (key.code === '[B') {
      currentIndex++
    } else if (key.sequence === '\r') {
      process.stdin.setRawMode(false)
      process.stdin.removeListener('keypress', keypresshandle)
      done(lineArray[currentIndex])
    }
    if (currentIndex < 0) currentIndex = 0
    if (currentIndex >= lineArray.length) currentIndex = lineArray.length - 1
    process.stdout.moveCursor(0, -lineArray.length)
    printLine()
  }

  // process.stdin.on('keypress', keypresshandle)
  process.stdin.addListener('keypress', keypresshandle)
}

/**
 * @param {string} command
 * @param {string[]} args
 * @param
 */
function execShell(command, args) {
  return new Promise((res, rej) => {
    let execShell = child_process.spawn(command, args)
    execShell.stdout.on('data', data => process.stdout.write(data.toString()))
    execShell.stderr.on('data', data => process.stderr.write(data.toString()))
    execShell.on('close', res)
  })
}

let httpGet = (url) => {
  return new Promise((res, rej) => {
    https.get(url,
    resp => {
      let data = ''
      resp.on('data', chunk => {
        data += chunk
      })
      resp.on('end', () => {
        res(JSON.parse(data))
      })
    }).on('error', rej)
  })
}

/**
 * 
 * @param {string} path 
 * @param {(file:string, name:string)=>{}} callback 
 */
async function visitAllFile(path, callback) {
  const dir = await fs.promises.opendir(path)
  let promises = []
  for await (const dirent of dir) {
      if (dirent.isDirectory() && dirent.name.search(/^\./) < 0) {
          let res = visitAllFile(`${path}/${dirent.name}`, callback)
          promises.push(res)
      } else {
          callback(`${path}/${dirent.name}`, dirent.name)
      }
  }
  await Promise.all(promises)
}