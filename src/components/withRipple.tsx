import React from 'react';
import {withRipple, InjectedProps} from '@material/react-ripple';

interface IconProps extends InjectedProps<HTMLDivElement> {
    children?: React.ReactNode;
    className: string;
    initRipple: React.Ref<HTMLDivElement>;
    unbounded: boolean;
    onClick?: () => void;
}

const Icon = (props: IconProps) => {
    const {
        children,
        className = '',
        // You must call `initRipple` from the root element's ref. This attaches the ripple
        // to the element.
        initRipple,
        // include `unbounded` to remove warnings when passing `otherProps` to the
        // root element.
        unbounded,
        ...otherProps
    } = props;
    
    // any classes needed on your component needs to be merged with
    // `className` passed from `props`.
    const classes = `ripple-icon-component ${className}`;
    
    return (
        <div
            className={classes}
            ref={initRipple}
            {...otherProps}>
            {children}
        </div>
    );
};

export const RippleIcon = withRipple<IconProps, HTMLDivElement>(Icon);