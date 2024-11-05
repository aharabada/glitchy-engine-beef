import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.tsx'
import './assets/Fonts/Inter/inter.css'
import './index.css'
import 'dockview/dist/styles/dockview.css';

// Ultralight 1.4 = Safari 16.4.1 / WebKit 615.1.18.100.1 (March 2023)

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
