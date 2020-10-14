import { ipcRenderer, contextBridge } from 'electron'

declare global {
    interface Window {
        api: {
            send: (channel: string, data: any) => void,
            on: (channel: string, func: (args? :any) => void) => void,
            once: (channel: string, func: (args? :any) => void) => void,
            removeAllListeners: (channels: string[]) => void
        }
    }
}

const validSendChannels = [
    'showDialog', 
    'showOpenDialog', 
    'merge'
]

const validReceiveChannels = [
    'merge:progress', 
    'merge:complete', 
    'merge:cancel', 
    'merge:error', 
    'merge:start', 
    'merge:waiting',
    'showOpenDialog:response'
]

contextBridge.exposeInMainWorld(
    'api', {
        send: (channel: string, data: any) => {
            if (validSendChannels.includes(channel)) {
                ipcRenderer.send(channel, data);
            }
        },
        on: (channel: string, func: (args?: any) => void) => {
            if (validReceiveChannels.includes(channel)) {
                ipcRenderer.on(channel, (event: any, ...args: any) => func(...args));
            }
        },
        once: (channel: string, func: (args?: any) => void) => {
            if (validReceiveChannels.includes(channel)) {
                ipcRenderer.once(channel, (event: any, ...args: any) => func(...args));
            }
        },        
        removeAllListeners: (channels: string[]) => {
            channels.forEach(channel => {
                ipcRenderer.removeAllListeners(channel);
            })
        }
    }
);