import React, { Component } from "react";
import Header from "../modules/header/Header";
import Footer from "../modules/footer/Footer";
import OpensourceCharts from "../sections/opensourceCharts/OpensourceCharts";
import Organizations from "../sections/organizations/Organizations";
import PullRequests from "../sections/pullRequests/PullRequests";
import Issues from "../sections/issues/Issues";
import TopButton from "../modules/topButton/TopButton";
import "./Opensource.css";

class Opensource extends Component {
  render() {
    return (
      <div className="opensource-main">
        <Header theme={this.props.theme} />
        <Organizations theme={this.props.theme} />
        <OpensourceCharts theme={this.props.theme} />
        <PullRequests theme={this.props.theme} />
        <Issues theme={this.props.theme} />
        <Footer theme={this.props.theme} onToggle={this.props.onToggle} />
        <TopButton theme={this.props.theme} />
      </div>
    );
  }
}

export default Opensource;
