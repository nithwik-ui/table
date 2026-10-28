import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Layout from './components/Layout';
import Broadcast from './pages/Broadcast';
import TestClass from './pages/TestClass';
import { Holidays } from './pages/Holidays';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={<Broadcast />} />
          <Route path="test-class" element={<TestClass />} />
          <Route path="holidays" element={<Holidays />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;

