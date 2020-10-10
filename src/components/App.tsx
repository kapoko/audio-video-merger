import React, { useState } from 'react';
import DropZone from './DropZone';
import Processing from './Processing';
import validateFiles from '../lib/validateFiles';
import { processFilesRequest } from '../lib/interfaces';

enum ScreenState {
    SelectFiles,
    Processing
}

function App() {
    const { checkFiles } = validateFiles();
    const [screenState, setScreenState] = useState(ScreenState.SelectFiles);
    const [progress, setProgress] = useState(0);

    function handleDrop(files: FileList) {
        const request: processFilesRequest = checkFiles(files);

        if (!request.isValid) { 
            window.api.send('showDialog', {
                message: 'Select at least one audio and one video file.'
            });
             
            return;
        }

        setScreenState(ScreenState.Processing)
        window.api.send('merge', request);
        window.api.receive('merge:progress', p => {
            setProgress(p)
        });
        window.api.receive('merge:complete', arg => {
            setScreenState(ScreenState.SelectFiles);
            setProgress(0);
            new Notification('Merging videos complete', { body: arg });
        });
    }

    function renderScreen(screen: ScreenState) {
        switch (screen) {
            case ScreenState.SelectFiles:
                return <DropZone onDropFiles={handleDrop} />
            case ScreenState.Processing:
                return <Processing progress={progress} />
        }
    }

    return renderScreen(screenState);
}

export default App;