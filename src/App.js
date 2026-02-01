import React from "react";
import "./App.css";
import Main from "./sections/Main";
import { ThemeProvider } from "styled-components";
import { chosenTheme } from "./styles";
import { GlobalStyles } from "./constants";

function App() {
  return (
    <ThemeProvider theme={chosenTheme}>
      <>
        <GlobalStyles />
        <div>
          <Main theme={chosenTheme} />
        </div>
      </>
    </ThemeProvider>
  );
}

export default App;
