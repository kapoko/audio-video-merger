import React from 'react';
import { ProcessResult } from '../lib/interfaces';

export interface CompleteProps {
    result: ProcessResult
}

const Complete: React.FunctionComponent<CompleteProps> = (props: CompleteProps) => {
    const { processed, total } = props.result;

    return (
        <>
            <h1>Complete!</h1>
            <p><span role="img" aria-label="checkmark">✔️</span> Created { processed } of { total } videos.</p>
        </>
    )
}

export default Complete