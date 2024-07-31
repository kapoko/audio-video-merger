import type React from 'react';
import type { ProcessResult } from '../lib/interfaces';

export interface CompleteProps {
    result: ProcessResult
}

const Complete: React.FunctionComponent<CompleteProps> = (props: CompleteProps) => {
    const { processed, total } = props.result;

    return (
        <div>
            <h1>Complete!</h1>
            <p><span role="img" aria-label="checkmark">✔️</span> Created { processed } of { total } videos.</p>
        </div>
    )
}

export default Complete