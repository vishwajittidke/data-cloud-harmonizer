import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import d3Resource from '@salesforce/resourceUrl/d3';
import fetchDashboardData from '@salesforce/apex/IdentityResolutionEngine.fetchDashboardData';
import runHarmonizationAura from '@salesforce/apex/IdentityResolutionEngine.runHarmonizationAura';
import isBatchRunning from '@salesforce/apex/IdentityResolutionEngine.isBatchRunning';
import resetDemo from '@salesforce/apex/IdentityResolutionEngine.resetDemo';
import injectMockData from '@salesforce/apex/IdentityResolutionEngine.injectMockData';
import getLineageData from '@salesforce/apex/IdentityResolutionEngine.getLineageData';
import getResolutionQueue from '@salesforce/apex/IdentityResolutionEngine.getResolutionQueue';
import manualMerge from '@salesforce/apex/IdentityResolutionEngine.manualMerge';
import manualUnmerge from '@salesforce/apex/IdentityResolutionEngine.manualUnmerge';
import { refreshApex } from '@salesforce/apex';

export default class DataCloudExplorer extends LightningElement {
    @track subscribers = [];
    @track posRecords = [];
    @track unifiedRecords = [];
    @track isProcessing = false;
    @track activeTab = 'dashboard';

    wiredDataResult;

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

    handleInjectData() {
        this.isProcessing = true;
        injectMockData()
            .then(() => refreshApex(this.wiredDataResult))
            .catch(err => console.error(err))
            .finally(() => this.isProcessing = false);
    }

    handleReset() {
        this.isProcessing = true;
        resetDemo()
            .then(() => refreshApex(this.wiredDataResult))
            .catch(err => console.error(err))
            .finally(() => this.isProcessing = false);
    }

    handleRunHarmonization() {
        this.isProcessing = true;
        runHarmonizationAura()
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Engine Started',
                        message: 'Processing identities in the background... please wait.',
                        variant: 'info'
                    })
                );
                
                this.pollBatchStatus();
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body ? error.body.message : error.message,
                        variant: 'error'
                    })
                );
                this.isProcessing = false;
            });
    }

    pollBatchStatus() {
        isBatchRunning()
            .then(isRunning => {
                if (isRunning) {
                    setTimeout(() => {
                        this.pollBatchStatus();
                    }, 2000);
                } else {
                    refreshApex(this.wiredDataResult).then(() => {
                        this.isProcessing = false;
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Success',
                                message: 'Data Harmonization Complete! UI Auto-Refreshed.',
                                variant: 'success'
                            })
                        );
                    });
                }
            })
            .catch(err => console.error(err));
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
            .finally(() => this.isQueueLoading = false);
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
        
        this.isProcessing = true;
        
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
                this.isProcessing = false;
            });
    }
    handleReset() {
        this.isProcessing = true;
        resetDemo()
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Reset Successful', message: 'Demo data cleared.', variant: 'success' }));
                return refreshApex(this.wiredDataResult);
            })
            .catch(err => console.error(err))
            .finally(() => this.isProcessing = false);
    }

    handleInjectData() {
        this.isProcessing = true;
        injectMockData()
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Data Injected', message: 'Mock data created successfully.', variant: 'success' }));
                return refreshApex(this.wiredDataResult);
            })
            .catch(err => console.error(err))
            .finally(() => this.isProcessing = false);
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
        // Wait for DOM to render the manual div
        setTimeout(() => {
            const container = this.template.querySelector('.d3-container');
            if (!container) return;
            
            // Clear previous graph
            container.innerHTML = '';
            
            const width = container.clientWidth || 800;
            const height = container.clientHeight || 500;
            
            const svg = d3.select(container)
                .append('svg')
                .attr('width', '100%')
                .attr('height', '100%')
                .attr('viewBox', [0, 0, width, height]);
                
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
                    if (d.group === 1) return '#FFB75D'; // Golden Record
                    if (d.group === 2) return '#4BC076'; // Subscriber
                    return '#54698D'; // POS
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
        return d3.drag()
            .on('start', dragstarted)
            .on('drag', dragged)
            .on('end', dragended);
    }
}
