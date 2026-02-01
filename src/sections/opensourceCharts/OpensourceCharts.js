import React, { Component } from "react";
import PullRequestChart from "../modules/pullRequestChart/PullRequestChart.js";
import IssueChart from "../modules/issueChart/IssueChart.js";
import { Fade } from "react-reveal";
import "./OpensourceCharts.css";

class OpensourceCharts extends Component {
  render() {
    const theme = this.props.theme;
    return (
      <div className="main-div">
        <div className="os-charts-header-div">
          <Fade bottom duration={2000} distance="20px">
            <h1 className="os-charts-header" style={{ color: theme.text }}>
              Contributions
            </h1>
          </Fade>
        </div>
        <div className="os-charts-body-div">
          <PullRequestChart />
          <IssueChart />
        </div>
      </div>
    );
  }
}

export default OpensourceCharts;
