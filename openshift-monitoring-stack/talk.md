# Openshift 4 Monitoring Stack
### David Kirwan


#### a quick overview

<!--
  Comments are removed. They must be
  in the form of an HTML comment tag.
-->

# Components
The [Openshift monitoring stack][1] is made up of the following components:

- [Prometheus][3]
- [Alertmanager][4]
- [Grafana][8]

While this stack comes preinstalled on Openshift 4 clusters, it is only accessible by default to cluster administrators. The purpose of this stack is to monitor the health of the Openshift cluster itself.

It is possible to monitor your own applications using the [User Workload Monitoring][9] stack. This integrates with the cluster monitoring stack in important ways such as being able to avail of the Alertmanager integration for creating alerts when services go down.


  [1]: https://github.com/openshift/cluster-monitoring-operator
  [2]: https://github.com/openshift/prometheus-operator
  [3]: https://github.com/prometheus/prometheus
  [4]: https://github.com/prometheus/alertmanager
  [5]: https://github.com/kubernetes/kube-state-metrics
  [6]: https://github.com/prometheus/node_exporter
  [7]: https://github.com/DirectXMan12/k8s-prometheus-adapter
  [8]: https://github.com/grafana/grafana
  [9]: https://docs.openshift.com/container-platform/4.5/monitoring/monitoring-your-own-services.html


# Prometheus Architecture
Prometheus operates on a HTTP __pull model__. Prometheus must have direct network access to the service exposing metrics data. You __cannot push__ data to Prometheus.

If you are ever in the position where you have a short lived job exposing metrics which you wish to capture you can make use of the [Prometheus Pushgateway][1]. This is a service which you can push your metric data to, and have Prometheus scrape it. Just keep in mind you are in control of the metric data and lifecycle, delete old stale data if required.

Prometheus works best for __whitebox__ monitoring. ie: You operate an application which already exposes metrics, or are developing one which you wish to add metrics to.

If you are in the position where you wish to monitor services which you do not control, you can use the [Prometheus blackbox exporter][2]. Uses might include, checking that a host is up using a http check.


  [1]: https://github.com/prometheus/pushgateway
  [2]: https://github.com/prometheus/blackbox_exporter


# Prometheus Data Types
Prometheus offers multiple metric data types [Prometheus Data Types][1] which you can expose in your application.

All data types have the ability to add labels, where you can store extra metadata. Just keep in mind if you put some data which can change dynamically, it will create a unique metric with that unique label value, so don't use it to store dynamic data etc unless you want this behaviour.

eg:

```
  # HELP crypto_eth_eur The spot price of Ethereum in Euro
  # TYPE crypto_eth_eur gauge
  crypto_eth_eur{currency1="Ethereum", ticker1="ETH", currency2="Euro", ticker2="EURO", exchange="Coinbase"} 289.47
```

#### Counter
Counters can be reset to 0, and can only increase. eg: used to count the number of requests served by an application

#### Gauge
A gauge is a metric which represents a single numerical value. It can go up or down. Think of an Int/Float.

#### Histogram
A histogram metric, takes a sample of the possible values and stores them in buckets. A number of metrics get created automatically, eg __metricname_count__, and __metricname_sum__. You might use a histogram metric to count the number of requests which might complete within a certain timeframe.

#### Summary
Similar to a histogram metric, Summary has similar features and some extra, such as calculating quantiles over a sliding time window. For more detailed information see [Summary Quantiles][2]


  [1]: https://prometheus.io/docs/concepts/metric_types/
  [2]: https://prometheus.io/docs/practices/histograms/#quantiles


# Exposing metrics
Exposing metrics is really easy. In your app, make an endpoint available which returns the metric data in a format which adheres to the [Prometheus data model][1].

Next update the Prometheus configuration to tell it to scrape your applications metrics endpoint. Easy!

An example shown earlier. The __HELP__ is the metric description. This is a gauge, you can see from the __TYPE__ which lists its name and __gauge__. Next you can see the name of the metric which is __crypto_eth_eur__, and it has various labels. Finall the value is __289.47__.

```
  # HELP crypto_eth_eur The spot price of Ethereum in Euro
  # TYPE crypto_eth_eur gauge
  crypto_eth_eur{currency1="Ethereum", ticker1="ETH", currency2="Euro", ticker2="EURO", exchange="Coinbase"} 289.47
```

Be sure to read the [best practices][2] for naming metrics and labels.


  [1]: https://prometheus.io/docs/concepts/data_model/
  [2]: https://prometheus.io/docs/practices/naming/



# Querying metrics
Prometheus has a very powerful query language called __PromQL__. You can build up very rich an complex queries and join metrics together much like you would in SQL with table joins etc.

Likewise there is a mature ecosystem of support to query metrics programatically. There are various libraries in modern high level languages which you can use eg:

- Go
- Java
- Python
- Ruby


  [1]: https://prometheus.io/docs/prometheus/latest/querying/basics/


# How does this work on Openshift
OK I mentioned in the exposing metrics slide previously that its easy! Yeah it is outside Openshift that is, but inside its bloody complex if you are not already familiar with development of applications for Kubernetes/Openshift. If you are familiar, its easy ;).

Prometheus inside Openshift is managed by an Operator.

### Operators
It's a __Custom Resource Controller__.

- __Resource Controllers__ are the logic which manages Kubernetes API object types eg: (Pod, Deployment, PV, PVC etc).
- An Operator is a design pattern, we have a [framework/sdk][1] which we use to build and develop these operators. 
- Custom Resource Controllers __extend__ the Kubernetes API
- With the purposes of creating a (potentially autonomous) application which manages the lifecycle of another application.


  [1]: https://github.com/operator-framework/operator-sdk


# Prometheus Operator
I'll mention a few of the steps to get your apps metrics being picked up. Ok, Prometheus inside Openshift is managed by the __Prometheus Operator__. We can interact with this operator using these special objects:

- ServiceMonitor / PodMonitor
- PrometheusRule

#### ServiceMonitor
This is an object which configures Prometheus to scrape your Service. The Service should be configured to map to the application and port. By default, the service monitor will tell Prometheus to scrape __http://yourapp.svc:port/metrics__.

#### PodMonitor
This is an object which configures Prometheus to scrape a particular Pod.

#### PrometheusRule
A PrometheusRule is an object which contains a rule which we want to create an alert for. eg:

- 95% of Fedoras mirror network should be responding to requests in less than 50milliseconds

Do what ever PromQL magic to get this data returned, put it in the PrometheusRule rule and tell Prometheus how often to check this eg every 5 minutes. If that ever ceases to be true, it will create an alert.


# Alertmanager
Alertmanager is automagically configured by default to query the Prometheus instances and look for alerts which are firing. If they are firing, you can configure Alertmanager to do things based on severity. eg:

- warning: just send an email
- critical: call Pagerduty and create an alert to ping the SRE folks to wake up and fix it!!




# Demo
Quick demo with all these features I've spoken about so far. See this sample application I've prepared earlier:

- Built using [presenting.vim][1]

  [1]: https://github.com/sotte/presenting.vim
  [2]: https://github.com/davidkirwan/asset_monitoring

### Fin!
