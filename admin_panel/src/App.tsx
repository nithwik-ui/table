import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import Broadcast from './pages/Broadcast';
import TestClass from './pages/TestClass';
import { Holidays } from './pages/Holidays';
import { FacultyManagement } from './pages/FacultyManagement';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={<Broadcast />} />
          <Route path="test-class" element={<TestClass />} />
          <Route path="holidays" element={<Holidays />} />
          <Route path="faculty" element={<FacultyManagement />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
