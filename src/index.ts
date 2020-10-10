import { app, BrowserWindow, ipcMain, dialog } from 'electron';
import * as ffmpeg from 'fluent-ffmpeg';
import { processFilesRequest, singleProcessOptions } from './lib/interfaces';
import * as path from 'path';
declare const MAIN_WINDOW_WEBPACK_ENTRY: any;
declare const MAIN_WINDOW_PRELOAD_WEBPACK_ENTRY: any;

// Handle creating/removing shortcuts on Windows when installing/uninstalling.
if (require('electron-squirrel-startup')) { // eslint-disable-line global-require
  app.quit();
}

let mainWindow: BrowserWindow;
const gotTheLock = app.requestSingleInstanceLock()

const createWindow = (): void => {
  // Create the browser window.
  mainWindow = new BrowserWindow({
    width: 640,
    height: 480,
    resizable: false,
    show: false,
    webPreferences: {
      nodeIntegration: false,
      worldSafeExecuteJavaScript: true,
      contextIsolation: true,
      preload: MAIN_WINDOW_PRELOAD_WEBPACK_ENTRY,
      devTools: !app.isPackaged
    }
  });

  console.log(MAIN_WINDOW_PRELOAD_WEBPACK_ENTRY);

  mainWindow.loadURL(MAIN_WINDOW_WEBPACK_ENTRY);

  if (!app.isPackaged) {
    mainWindow.webContents.openDevTools();
  }

  mainWindow.once('ready-to-show', () => {
    mainWindow.show()
  })
};

if (!gotTheLock) {
  app.quit()
} else {
  app.on('second-instance', (event, commandLine, workingDirectory) => {
    // Someone tried to run a second instance, we should focus our window.
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore()
      mainWindow.focus()
    }
  })

  // Create myWindow, load the rest of the app, etc...
  app.on('ready', createWindow);
}

if (process.argv.length >= 2) {
  const filePath = process.argv[1]
  console.log(filePath);
}

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

//Get the paths to the packaged versions of the binaries we want to use
const ffmpegPath = require('ffmpeg-static').replace(
  'app.asar',
  'app.asar.unpacked'
);
const ffprobePath = require('ffprobe-static').path.replace(
    'app.asar',
    'app.asar.unpacked'
);

ffmpeg.setFfmpegPath(ffmpegPath);
ffmpeg.setFfprobePath(ffprobePath);

function processVideo(options: singleProcessOptions) {
  return new Promise((resolve, reject) => {
    ffmpeg.default()
      .input(options.videoPath)
      .addInput(options.audioPath)
      .outputOptions([
        '-c:v copy',
        '-map 0:v:0',
        '-map 1:a:0'
      ])
      .on('end', resolve)
      .on('error', reject)
      .save(options.output);
  }); 
}

ipcMain.on('merge', async (event, input: processFilesRequest) => {
  const { video, audio } = input;

  let processChain: singleProcessOptions[] = [];

  // Loop over all videos and audio
  video.forEach((videoPath, index) => {
    audio.forEach(audioPath => {
      const dir = path.dirname(videoPath);
      const fileName = path.basename(audioPath, path.extname(audioPath)) + path.extname(videoPath);
      const videoBaseName = path.basename(videoPath, path.extname(videoPath));

      const output = video.length > 1 ? path.join(dir, videoBaseName + '_' + fileName) : path.join(dir, fileName)

      processChain.push({ videoPath, audioPath, output });
    });
  });

  let processCount = 0;
  for (const options of processChain) {
    await processVideo(options).catch(console.error).then(() => {
      event.reply('merge:progress', `${++processCount} of ${processChain.length} videos complete`)
    });
  }

  event.reply('merge:complete', `✅ Processed ${processCount} of ${processChain.length} videos`)
});

ipcMain.on('showDialog', (event, options) => {
  dialog.showMessageBox(mainWindow, options);
});