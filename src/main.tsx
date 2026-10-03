import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import './styles.css';

class AppErrorBoundary extends React.Component<{children:React.ReactNode},{hasError:boolean;message:string}>{
  constructor(props:{children:React.ReactNode}){super(props);this.state={hasError:false,message:''}}
  static getDerivedStateFromError(error:unknown){return {hasError:true,message:error instanceof Error?error.message:String(error)}}
  componentDidCatch(error:unknown){console.error('Error al cargar el sistema:',error)}
  render(){if(this.state.hasError)return <div className="setup"><div className="login-card"><h1>No se pudo abrir el sistema</h1><p>La aplicación encontró un error de ejecución. Copia este mensaje y envíaselo al desarrollador:</p><pre style={{whiteSpace:'pre-wrap',fontSize:12,color:'#a83c36'}}>{this.state.message}</pre><button className="secondary full" onClick={()=>window.location.reload()}>Volver a intentar</button></div></div>;return this.props.children}
}

createRoot(document.getElementById('root')!).render(<React.StrictMode><AppErrorBoundary><App /></AppErrorBoundary></React.StrictMode>);
