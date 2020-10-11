import React, { useState } from 'react';
import DropZone from './DropZone';
import Processing from './Processing';
import validateFiles from '../lib/validateFiles';
import { ProcessFilesRequest, ProcessResult } from '../lib/interfaces';
import Complete from './Complete';

enum ScreenState {
    SelectFiles,
    Processing,
    Complete
}

function App() {
    const { checkFiles } = validateFiles();
    const [screenState, setScreenState] = useState<ScreenState>(ScreenState.SelectFiles);
    const [progress, setProgress] = useState(0);
    const [result, setResult] = useState<ProcessResult>({ processed: 0, total: 0 });

    function handleDrop(files: FileList) {
        const request: ProcessFilesRequest = checkFiles(files);

        if (!request.isValid) { 
            window.api.send('showDialog', {
                message: 'Select at least one audio and one video file.'
            });
             
            return;
        }

        process(request);
    }

    function process(request: ProcessFilesRequest) {
        setScreenState(ScreenState.Processing)
        window.api.send('merge', request);
        window.api.receive('merge:progress', p => {
            setProgress(p)
        });
        window.api.receive('merge:cancel', () => {
            setScreenState(ScreenState.SelectFiles);
        });
        window.api.receive('merge:complete', (res: ProcessResult) => {
            setScreenState(ScreenState.Complete);
            setProgress(0);
            setResult(res)
            new Notification('Merging videos complete', { body: `✅ Created ${res.processed} of ${res.total} videos.`});
            setTimeout(() => {
                setScreenState(ScreenState.SelectFiles)
            }, 2000)
        });
    }

    function renderScreen(screen: ScreenState) {
        switch (screen) {
            case ScreenState.SelectFiles:
                return <DropZone onDropFiles={handleDrop} />
            case ScreenState.Processing:
                return <Processing progress={progress} />
            case ScreenState.Complete:
                return <Complete result={result} />
        }
    }

    return renderScreen(screenState);
}

export default App;