import React, { Component } from "react";
import Header from "../modules/header/Header";
import Greeting from "../sections/greeting/Greeting";
import Skills from "../sections/skills/Skills";
import Footer from "../modules/footer/Footer";
import TopButton from "../modules/topButton/TopButton";

class Home extends Component {
  render() {
    return (
      <div>
        <Header theme={this.props.theme} />
        <Greeting theme={this.props.theme} />
        <Skills theme={this.props.theme} />
        <Footer theme={this.props.theme} />
        <TopButton theme={this.props.theme} />
      </div>
    );
  }
}

export default Home;
