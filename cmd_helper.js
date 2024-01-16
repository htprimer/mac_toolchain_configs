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

const httpPost = (url, body) => {
  return new Promise((res, rej) => {
    let req = http.request(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      }
    }, resp => {
      let data = ''
      resp.on('data', chunk => {
        data += chunk
      })
      resp.on('end', () => {
        res(JSON.parse(data))
      })
    })
    req.on('error', rej)
    body && req.write(JSON.stringify(body))
    req.end()
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

async function fetchBranch(repo) {
    if (repo.startsWith('~/')) {
        repo = repo.replace('~/', `${process.env.HOME}/`)
    }
    let result = await execShell('git branch', {cwd: repo})
    result = result.split('\n').find(line => {
        return line.startsWith('*')
    })
    let branch = null
    if (result.indexOf('detached at') >= 0) {
        branch = (result.match(/at ([^ )]+)\)/))[1]
    } else {
        branch = result.split(' ').pop()
    }
    return branch
}

function execShell(command, options) {
    return new Promise((res, rej) => {
        child_process.exec(command, options, (err, stdout, stderr) => {
            if (err) {
                rej(err)
            } else {
                res(stdout)
            }
            process.stderr.write(stderr)
        })
    })
}

async function showDepend() {
    let podfile = `${process.env.PWD}/Podfile`
    let fileLines = null
    try {
        fileLines = (await fs.promises.readFile(podfile)).toString().split('\n')
    } catch (error) {
        console.error(error)
    }
    let pathBranchDict = {}
    await Promise.all(fileLines.map(async line => {
        if (!line.trim().startsWith('#') && line.indexOf(':path') >= 0) {
            let result = line.match(/:path *=> *'([\S]+)'/)
            let branch = await fetchBranch(result[1])
            pathBranchDict[result[1]] = branch
        }
    }))
    console.log(pathBranchDict)
}
