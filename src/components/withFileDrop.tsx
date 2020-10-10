import React, { useState } from 'react';

export interface WithFileDropProps {
    loading: boolean;
    asdf: string;
}

// function withFileDrop<WithFileDropProps>(Component: React.ComponentType<WithFileDropProps>) {
//     function handleDrop(event: React.DragEvent<HTMLDivElement>) {
//         event.preventDefault();
//         event.stopPropagation();
//         console.log(event)
//     }

//     return (props: WithFileDropProps) => (
//         <Component {...props} onDrop={props.asdf} />
//     )
// }

// export function withFileDrop<P>(
//     // Then we need to type the incoming component.
//     // This creates a union type of whatever the component
//     // already accepts AND our extraInfo prop
//     WrappedComponent: React.ComponentType<P & WithFileDropProps>
//   ) {
//     const [extraInfo, setExtraInfo] = useState('');
//     setExtraInfo('important data.');
  
//     const ComponentWithExtraInfo = (props: P) => {
//       // At this point, the props being passed in are the original props the component expects.
//       return <WrappedComponent {...props} />;
//     };
//     return ComponentWithExtraInfo;
//   }


// const withFileDrop = <T extends object>(
//     Component: React.ComponentType<T>
//   ): React.FC<T & WithFileDropProps> => ({
//     ...props
//   }: WithFileDropProps) => (
//       <Component asdf="jaja" {...props as T} />
//   )

// export default withFileDrop;