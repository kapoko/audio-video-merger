"use strict";
const electron = require("electron");
const validSendChannels = [
  "showDialog",
  "showOpenDialog",
  "merge"
];
const validReceiveChannels = [
  "merge:progress",
  "merge:complete",
  "merge:cancel",
  "merge:error",
  "merge:start",
  "merge:waiting",
  "showOpenDialog:response"
];
electron.contextBridge.exposeInMainWorld(
  "api",
  {
    send: (channel, data) => {
      if (validSendChannels.includes(channel)) {
        electron.ipcRenderer.send(channel, data);
      }
    },
    on: (channel, callback) => {
      if (validReceiveChannels.includes(channel)) {
        electron.ipcRenderer.on(channel, (event, ...args) => callback(...args));
      }
    },
    once: (channel, callback) => {
      if (validReceiveChannels.includes(channel)) {
        electron.ipcRenderer.once(channel, (event, ...args) => callback(...args));
      }
    },
    removeAllListeners: (channels) => {
      channels.forEach((channel) => {
        electron.ipcRenderer.removeAllListeners(channel);
      });
    }
  }
);
