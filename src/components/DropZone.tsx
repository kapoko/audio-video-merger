import React, { useState, useEffect, useReducer } from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faFolderOpen } from '@fortawesome/free-solid-svg-icons'
import { FileInfo } from '../lib/interfaces';
import { RippleButton } from './RippleButton';

export interface DropZoneProps {
    onDropFiles(files: FileList): void
    onOpenFiles(fileInfoList: FileInfo[]): void
}

const quotes: string[] = [
    'Cast it into the fire! 🔥'
]

function quoteReducer(currentQuote: number): number {
    let newQuote: number = currentQuote;

    while((newQuote === -1 || quotes.length > 1) && newQuote === currentQuote) {
        newQuote = Math.floor(Math.random() * quotes.length);
    }

    return newQuote;
}

const DropZone: React.FunctionComponent<DropZoneProps> = (props: DropZoneProps) => {

    const [dragging, setDragging] = useState(false);
    const [enterTarget, setEnterTarget] = useState<EventTarget>();
    const [quoteIndex, switchQuote] = useReducer(quoteReducer, -1); 

    useEffect(() => {
        if (!dragging) {
            switchQuote();
        }
    }, [dragging]);
    
    function handleDrop(event: React.DragEvent) {
        event.preventDefault();
        event.stopPropagation();

        if (!dragging) {
            return;
        }

        setDragging(false);

        const { files } = event.dataTransfer;
        props.onDropFiles(files);
    }

    function handleDragEnter(e: React.DragEvent) {
        setEnterTarget(e.target);
        setDragging(true);
    }

    function handleDragLeave(e: React.DragEvent) {
        if (e.target === enterTarget) {
            setDragging(false);
        }
    }

    function dragPreventDefault(event: React.DragEvent) {
        event.preventDefault();
    }

    function handleClick() {
        window.api.send('showOpenDialog', {
            message: 'Select audio and video files',
            properties: ['openFile', 'multiSelections']
        });

        window.api.once('showOpenDialog:response', (fileInfoList: FileInfo[]) => {
            if (fileInfoList.length) {
                props.onOpenFiles(fileInfoList);
            }
        });
    }

    return (
        <div id="drop-zone" className={`drop-zone ${dragging ? 'is-dragging' : ''}`}
            onDrop={handleDrop} 
            onDragOver={dragPreventDefault} 
            onDragEnter={handleDragEnter}
            onDragLeave={handleDragLeave}>
            <div className="gradient-border"></div>
            <div className="inner">
                { !dragging
                    ? <h1>Drop audio and video files here</h1>
                    : <h1>{ quotes[quoteIndex] }</h1>
                }
                <RippleButton className="mdc-fab" onClick={handleClick} />
            </div>
        </div>
    );
}

export default DropZone
