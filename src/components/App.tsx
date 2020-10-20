import React, { useEffect, useState, useCallback, useRef } from 'react';
import { SwitchTransition, CSSTransition } from "react-transition-group";
import DropZone from './DropZone';
import Processing from './Processing';
import Complete from './Complete';
import { ProcessFilesRequest, ProcessResult, FileInfo } from '../lib/interfaces';
import { createRequestFromFileList, createRequestFromFileInfo } from '../lib/validateFiles';
import { baseName } from '../lib/helpers';

enum ScreenState {
    SelectFiles,
    Processing,
    Complete
}

const App: React.FunctionComponent = () => {
    
    const [screenState, setScreenState] = useState<ScreenState>(ScreenState.SelectFiles);
    const [progress, setProgress] = useState<number>(0);
    const [isProcessComplete, setProcessComplete] = useState(false);
    const [result, setResult] = useState<ProcessResult>({ processed: 0, total: 0, errors: [] });

    const handleOpenFiles = useCallback((files: FileInfo[]) => {
        const request = createRequestFromFileInfo(files);
        process(request);
    }, []);
    
    useEffect(() => {
        window.api.on('merge:waiting', () => {
            setScreenState(ScreenState.Processing);
        });
        window.api.on('merge:start', handleOpenFiles);
    }, [handleOpenFiles]);


    function handleDrop(files: FileList) {
        const request = createRequestFromFileList(files);
        process(request);
    }

    function process(request: ProcessFilesRequest) {
        setProcessComplete(false);

        if (!request.isValid) {
            const message = `Found ${request.videoList.length} video${request.videoList.length !== 1 ? 's' : ''} and ${request.audioList.length} audiofile${request.audioList.length !== 1 ? 's' : ''} in your request. Please select at least one of both. ${request.unrecognized.length ? `(Unrecognized files: ` + request.unrecognized.map(file => `${baseName(file.path)})`) : ''}`

            window.api.send('showDialog', {
                message: message
            });
            setScreenState(ScreenState.SelectFiles);
            return;
        }

        setScreenState(ScreenState.Processing); // Start merging

        window.api.send('merge', request); // Listen for responses

        window.api.on('merge:progress', (p: number) => {
            setProgress(p);
        });
        window.api.once('merge:cancel', () => {
            setScreenState(ScreenState.SelectFiles);
            setProcessComplete(true);
        });
        window.api.once('merge:error', (res: ProcessResult) => {
            new Notification('Something went wrong', {
                body: `Generated ${res.errors.length} errors. Created ${res.processed} of ${res.total} videos.`
            });
            console.error(res.errors);
            setProcessComplete(true);
            setScreenState(ScreenState.SelectFiles);
        });
        window.api.once('merge:complete', (res: ProcessResult) => {
            setScreenState(ScreenState.Complete);
            setResult(res);
            new Notification('Merging videos complete', {
                body: `✅ Created ${res.processed} of ${res.total} videos.`
            });
            setTimeout(() => {
                setScreenState(ScreenState.SelectFiles);
            }, 2000);
            setProcessComplete(true);
        });
    } 
    
    // Clean up after process is complete
    useEffect(() => {
        if (isProcessComplete) {
            setProgress(0);
            window.api.removeAllListeners(['merge:progress']);
        }
    }, [isProcessComplete]);

    function renderScreen(screen: ScreenState) {
        switch (screen) {
        case ScreenState.SelectFiles:
            return <DropZone onDropFiles={handleDrop} onOpenFiles={handleOpenFiles} />
        case ScreenState.Processing:
            return <Processing progress={progress} />
        case ScreenState.Complete:
            return <Complete result={result} />
        }
    }

    const nodeRef = useRef<HTMLDivElement>(document.createElement('div'));

    return (
        <SwitchTransition>
            <CSSTransition
                key={screenState}
                nodeRef={nodeRef}
                addEndListener={(done: () => void) => {
                    nodeRef.current.addEventListener("transitionend", done, false);
                }}
                classNames="fade">
                <div className="transition-wrap" ref={nodeRef}>
                    { renderScreen(screenState) }
                </div>
            </CSSTransition>
        </SwitchTransition>
    )
}

export default App;