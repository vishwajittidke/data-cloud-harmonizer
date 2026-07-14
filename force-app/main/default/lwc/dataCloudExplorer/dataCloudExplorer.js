import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import d3Resource from '@salesforce/resourceUrl/d3';
import fetchDashboardData from '@salesforce/apex/IdentityResolutionEngine.fetchDashboardData';
import runHarmonizationAura from '@salesforce/apex/IdentityResolutionEngine.runHarmonizationAura';
import getBatchProgress from '@salesforce/apex/IdentityResolutionEngine.getBatchProgress';
import resetDemo from '@salesforce/apex/IdentityResolutionEngine.resetDemo';
import injectMockData from '@salesforce/apex/IdentityResolutionEngine.injectMockData';
import getLineageData from '@salesforce/apex/IdentityResolutionEngine.getLineageData';
import getResolutionQueue from '@salesforce/apex/IdentityResolutionEngine.getResolutionQueue';
import manualMerge from '@salesforce/apex/IdentityResolutionEngine.manualMerge';
import manualUnmerge from '@salesforce/apex/IdentityResolutionEngine.manualUnmerge';
import generateInsights from '@salesforce/apex/AgentforceIntegrationService.generateInsights';
import { refreshApex } from '@salesforce/apex';

export default class DataCloudExplorer extends LightningElement {
    @track subscribers = [];
    @track posRecords = [];
    @track unifiedRecords = [];
    @track isProcessing = false;
    @track progressMessage = '';
    @track progressPercent = 0;
    @track showProgressBar = false;
    @track activeTab = 'dashboard';

    wiredDataResult;
    _pollTimeoutId = null;
    _safetyTimeoutId = null;

    @wire(fetchDashboardData)
    wiredData(result) {
        this.wiredDataResult = result;
        if (result.data) {
            this.subscribers = result.data.subscribers || [];
            this.posRecords = result.data.pos || [];
            this.unifiedRecords = result.data.unified || [];
        } else if (result.error) {
            console.error('Error fetching data', result.error);
        }
    }

    get hasRawData() {
        return (this.subscribers.length > 0 || this.posRecords.length > 0);
    }

    get hasUnifiedData() {
        return this.unifiedRecords && this.unifiedRecords.length > 0;
    }

    /**
     * Forces isProcessing = false. Called as a safety net to guarantee
     * the spinner can never get permanently stuck.
     */
    _forceStopProcessing() {
        if (this._pollTimeoutId) {
            clearTimeout(this._pollTimeoutId);
            this._pollTimeoutId = null;
        }
        if (this._safetyTimeoutId) {
            clearTimeout(this._safetyTimeoutId);
            this._safetyTimeoutId = null;
        }
        this.isProcessing = false;
        this.progressMessage = '';
        this.showProgressBar = false;
        this.progressPercent = 0;
    }

    /**
     * Arms a safety timeout. If the spinner is still active after maxMs,
     * force-kill it and show an error toast.
     */
    _armSafetyTimeout(maxMs) {
        if (this._safetyTimeoutId) {
            clearTimeout(this._safetyTimeoutId);
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._safetyTimeoutId = setTimeout(() => {
            if (this.isProcessing) {
                this._forceStopProcessing();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Timeout',
                        message: 'Operation timed out. Please try again.',
                        variant: 'warning'
                    })
                );
            }
        }, maxMs);
    }

    handleInjectData() {
        this.progressMessage = 'Injecting Mock Data...';
        this.isProcessing = true;
        this._armSafetyTimeout(30000);
        injectMockData()
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Data Injected', message: 'Mock data created successfully.', variant: 'success' }));
                return refreshApex(this.wiredDataResult);
            })
            .catch(err => {
                console.error(err);
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body ? err.body.message : err.message, variant: 'error' }));
            })
            .finally(() => { this._forceStopProcessing(); });
    }

    handleReset() {
        this.progressMessage = 'Clearing Demo Data...';
        this.isProcessing = true;
        this._armSafetyTimeout(30000);
        resetDemo()
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Reset Successful', message: 'Demo data cleared.', variant: 'success' }));
                return refreshApex(this.wiredDataResult);
            })
            .catch(err => {
                console.error(err);
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body ? err.body.message : err.message, variant: 'error' }));
            })
            .finally(() => { this._forceStopProcessing(); });
    }

    handleRunHarmonization() {
        this.progressMessage = 'Starting Harmonization...';
        this.isProcessing = true;
        this._armSafetyTimeout(60000); // 60s max for the entire operation

        runHarmonizationAura()
            .then(result => {
                if (result === 'EMPTY') {
                    // Nothing to process — kill spinner immediately
                    this._forceStopProcessing();
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'No Data',
                            message: 'No unprocessed records found. Inject messy data first!',
                            variant: 'warning'
                        })
                    );
                } else if (result === 'SYNC') {
                    // Already completed synchronously — refresh UI and kill spinner
                    refreshApex(this.wiredDataResult)
                        .then(() => {
                            this._forceStopProcessing();
                            this.dispatchEvent(
                                new ShowToastEvent({
                                    title: 'Success',
                                    message: 'Data Harmonization Complete!',
                                    variant: 'success'
                                })
                            );
                        })
                        .catch(() => {
                            // Even if refreshApex fails, kill spinner and reload data manually
                            this._forceStopProcessing();
                            this.dispatchEvent(
                                new ShowToastEvent({
                                    title: 'Done',
                                    message: 'Harmonization complete. Refresh page to see results.',
                                    variant: 'info'
                                })
                            );
                        });
                } else if (result === 'ASYNC') {
                    // Batch was kicked off — enter polling
                    this.progressMessage = 'Engine Started. Processing large dataset in background...';
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Engine Started',
                            message: 'Processing large dataset in background...',
                            variant: 'info'
                        })
                    );
                    this.pollBatchStatus();
                } else {
                    // Unknown result — kill spinner
                    this._forceStopProcessing();
                }
            })
            .catch(error => {
                this._forceStopProcessing();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body ? error.body.message : error.message,
                        variant: 'error'
                    })
                );
            });
    }

    pollBatchStatus() {
        if (this._pollTimeoutId) {
            clearTimeout(this._pollTimeoutId);
            this._pollTimeoutId = null;
        }

        getBatchProgress()
            .then(progress => {
                if (progress && progress.isRunning) {
                    
                    let statusStr = progress.status || 'Processing';
                    if (progress.total && progress.total > 0) {
                        this.showProgressBar = true;
                        this.progressPercent = Math.floor((progress.processed / progress.total) * 100);
                        this.progressMessage = `${statusStr}... (${this.progressPercent}%)`;
                    } else {
                        this.showProgressBar = false;
                        this.progressMessage = `${statusStr} large dataset...`;
                    }

                    // eslint-disable-next-line @lwc/lwc/no-async-operation
                    this._pollTimeoutId = setTimeout(() => {
                        this.pollBatchStatus();
                    }, 3000);
                } else {
                    this.progressMessage = 'Finishing up...';
                    refreshApex(this.wiredDataResult)
                        .then(() => {
                            this._forceStopProcessing();
                            this.dispatchEvent(
                                new ShowToastEvent({
                                    title: 'Success',
                                    message: 'Data Harmonization Complete! UI Auto-Refreshed.',
                                    variant: 'success'
                                })
                            );
                        })
                        .catch(() => {
                            this._forceStopProcessing();
                        });
                }
            })
            .catch(() => {
                this._forceStopProcessing();
            });
    }
    
    // --- Resolution Queue Logic ---
    @track unlinkedSubscribers = [];
    @track unlinkedPOS = [];
    @track isQueueLoading = false;
    @track isMergeModalOpen = false;
    @track selectedGoldenRecordId = '';
    
    currentSourceId = '';
    currentSourceType = '';

    pickerDisplayInfo = {
        primaryField: 'First_Name__c',
        additionalFields: ['Primary_Email__c']
    };

    pickerMatchingInfo = {
        primaryField: { fieldPath: 'First_Name__c' }
    };

    get isMergeDisabled() {
        return !this.selectedGoldenRecordId;
    }

    handleTabChange(event) {
        this.activeTab = event.target.value;
        if (this.activeTab === 'queue') {
            this.handleRefreshQueue();
        }
    }

    handleRefreshQueue() {
        this.isQueueLoading = true;
        getResolutionQueue()
            .then(result => {
                this.unlinkedSubscribers = result.unlinkedSubscribers || [];
                this.unlinkedPOS = result.unlinkedPOS || [];
            })
            .catch(err => console.error(err))
            .finally(() => { this.isQueueLoading = false; });
    }

    handleOpenMergeModal(event) {
        this.currentSourceId = event.target.dataset.id;
        this.currentSourceType = event.target.dataset.type;
        this.selectedGoldenRecordId = null;
        this.isMergeModalOpen = true;
    }

    handleCloseMergeModal() {
        this.isMergeModalOpen = false;
    }

    handleGoldenRecordChange(event) {
        this.selectedGoldenRecordId = event.detail.recordId;
    }

    handleExecuteMerge() {
        this.isQueueLoading = true;
        this.handleCloseMergeModal();
        
        manualMerge({ 
            sourceId: this.currentSourceId, 
            objectType: this.currentSourceType, 
            goldenId: this.selectedGoldenRecordId 
        })
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Merge Successful',
                    message: 'Record successfully linked to Golden Record.',
                    variant: 'success'
                })
            );
            this.handleRefreshQueue();
            return refreshApex(this.wiredDataResult);
        })
        .catch(err => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Merge Failed',
                    message: err.body ? err.body.message : err.message,
                    variant: 'error'
                })
            );
        })
        .finally(() => {
            this.isQueueLoading = false;
        });
    }

    handleUnmerge(event) {
        const sourceId = event.target.dataset.id;
        const sourceType = event.target.dataset.type;
        
        this.progressMessage = 'Unlinking Record...';
        this.isProcessing = true;
        this._armSafetyTimeout(15000);
        
        manualUnmerge({ sourceId: sourceId, objectType: sourceType })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Unlinked',
                        message: 'Record unlinked. You can find it in the Resolution Queue.',
                        variant: 'success'
                    })
                );
                return refreshApex(this.wiredDataResult);
            })
            .catch(err => {
                console.error(err);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Unlink Failed',
                        message: err.body ? err.body.message : err.message,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this._forceStopProcessing();
            });
    }
    
    // --- AI Insights Logic ---
    @track isAIModalOpen = false;
    @track isAILoading = false;
    @track aiSummaryText = '';

    handleAIInsights(event) {
        const recordId = event.target.dataset.id;
        const golden = this.unifiedRecords.find(r => r.Id === recordId);
        
        this.isAIModalOpen = true;
        this.isAILoading = true;
        this.aiSummaryText = '';

        const ltv = golden.Total_Lifetime_Value__c ? golden.Total_Lifetime_Value__c : 0;
        const fName = golden.First_Name__c ? golden.First_Name__c : 'Unknown';
        const conf = golden.Confidence_Score__c ? golden.Confidence_Score__c : 100;

        generateInsights({ firstName: fName, lifetimeValue: ltv, confidenceScore: conf })
            .then(result => {
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    this.aiSummaryText = result;
                    this.isAILoading = false;
                }, 1500); // Add a 1.5s simulated delay for realistic "AI generation" feel
            })
            .catch(error => {
                this.aiSummaryText = '<span style="color:red;">Error fetching insights: ' + (error.body ? error.body.message : error.message) + '</span>';
                this.isAILoading = false;
            });
    }

    handleCloseAIModal() {
        this.isAIModalOpen = false;
    }
    
    // --- D3 Graph Logic ---
    @track isGraphModalOpen = false;
    @track isGraphLoading = false;
    d3Initialized = false;

    handleOpenGraph(event) {
        const recordId = event.target.dataset.id;
        this.isGraphModalOpen = true;
        this.isGraphLoading = true;
        
        const promises = [];
        if (!this.d3Initialized) {
            promises.push(loadScript(this, d3Resource));
        }
        promises.push(getLineageData({ goldenRecordId: recordId }));

        Promise.all(promises).then(results => {
            this.d3Initialized = true;
            const data = results.length === 2 ? results[1] : results[0];
            this.isGraphLoading = false;
            this.renderD3Graph(data);
        }).catch(error => {
            console.error('Error loading graph', error);
            this.isGraphLoading = false;
        });
    }

    handleCloseGraph() {
        this.isGraphModalOpen = false;
    }

    renderD3Graph(data) {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const container = this.template.querySelector('.d3-container');
            if (!container) return;
            
            container.innerHTML = '';
            
            const width = container.clientWidth || 800;
            const height = container.clientHeight || 500;
            
            // eslint-disable-next-line no-undef
            const svg = d3.select(container)
                .append('svg')
                .attr('width', '100%')
                .attr('height', '100%')
                .attr('viewBox', [0, 0, width, height]);
                
            // eslint-disable-next-line no-undef
            const simulation = d3.forceSimulation(data.nodes)
                .force('link', d3.forceLink(data.links).id(d => d.id).distance(150))
                .force('charge', d3.forceManyBody().strength(-400))
                .force('center', d3.forceCenter(width / 2, height / 2));
                
            const link = svg.append('g')
                .attr('stroke', '#999')
                .attr('stroke-opacity', 0.6)
                .selectAll('line')
                .data(data.links)
                .join('line')
                .attr('stroke-width', 2);
                
            const node = svg.append('g')
                .attr('stroke', '#fff')
                .attr('stroke-width', 1.5)
                .selectAll('circle')
                .data(data.nodes)
                .join('circle')
                .attr('r', d => d.group === 1 ? 25 : 15)
                .attr('fill', d => {
                    if (d.group === 1) return '#FFB75D';
                    if (d.group === 2) return '#4BC076';
                    return '#54698D';
                })
                .call(this.drag(simulation));
                
            node.append('title')
                .text(d => d.label);
                
            const labels = svg.append('g')
                .selectAll('text')
                .data(data.nodes)
                .join('text')
                .attr('dy', 35)
                .attr('text-anchor', 'middle')
                .text(d => d.label)
                .style('font-size', '12px')
                .style('fill', '#333');
                
            simulation.on('tick', () => {
                link
                    .attr('x1', d => d.source.x)
                    .attr('y1', d => d.source.y)
                    .attr('x2', d => d.target.x)
                    .attr('y2', d => d.target.y);
                node
                    .attr('cx', d => d.x)
                    .attr('cy', d => d.y);
                labels
                    .attr('x', d => d.x)
                    .attr('y', d => d.y);
            });
        }, 100);
    }

    drag(simulation) {
        function dragstarted(event) {
            if (!event.active) simulation.alphaTarget(0.3).restart();
            event.subject.fx = event.subject.x;
            event.subject.fy = event.subject.y;
        }
        function dragged(event) {
            event.subject.fx = event.x;
            event.subject.fy = event.y;
        }
        function dragended(event) {
            if (!event.active) simulation.alphaTarget(0);
            event.subject.fx = null;
            event.subject.fy = null;
        }
        // eslint-disable-next-line no-undef
        return d3.drag()
            .on('start', dragstarted)
            .on('drag', dragged)
            .on('end', dragended);
    }
}
