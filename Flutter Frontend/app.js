import React from "react";
import Upload from "./Upload";
import "./App.css";

function App() {
  return (
    <div className="app">
      <h1>🥗 Diet AI</h1>
      <p>Upload your food image to get nutrition details</p>
      <Upload />
    </div>
  );
}

export default App;
