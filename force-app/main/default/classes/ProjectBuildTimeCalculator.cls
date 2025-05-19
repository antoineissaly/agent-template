/**
 * @description Calculates the estimated time to build a project or assemble items.
 * This class is designed to be called from AgentForce tools like Flow,
 * using an InvocableMethod.
 */
public with sharing class ProjectBuildTimeCalculator {

    // Constant: Average time in seconds for one builder to place one piece/item.
    private static final Integer SECONDS_PER_PIECE_SOLO = 12;
    // Constant: Number of seconds in an hour.
    private static final Integer SECONDS_PER_HOUR = 3600;

    /**
     * @description Inner class to define the input parameters for the InvocableMethod.
     * Each instance of this class represents a single request to calculate build time.
     */
    public class ProjectBuildRequest {
        @InvocableVariable(label='Number of Pieces' description='The total number of pieces in the project/set.' required=true)
        public Integer numberOfPieces;

        @InvocableVariable(label='Number of Builders' description='The number of people working on the project.' required=true)
        public Integer numberOfBuilders;
    }

    /**
     * @description Inner class to define the output parameters for the InvocableMethod.
     * Each instance of this class represents a single result containing the estimated build time.
     */
    public class ProjectBuildResponse {
        @InvocableVariable(label='Estimated Build Time (Hours)' description='The estimated time in hours to complete the project.')
        public Decimal estimatedTimeInHours;

        @InvocableVariable(label='Error Message' description='Error message if the calculation failed.')
        public String errorMessage;

        // Constructor for the response object
        // Renamed 'time' parameter to 'calculatedTime' to avoid reserved keyword conflict.
        public ProjectBuildResponse(Decimal calculatedTime, String errorMsg) {
            this.estimatedTimeInHours = calculatedTime;
            this.errorMessage = errorMsg;
        }
    }

    /**
     * @description Invocable method to calculate project build time.
     * This method can be called from Salesforce Flow or other automation tools.
     * It processes a list of requests and returns a list of corresponding responses.
     * @param requests A list of ProjectBuildRequest objects, each containing numberOfPieces and numberOfBuilders.
     * @return A list of ProjectBuildResponse objects, each containing the estimatedTimeInHours or an error message.
     */
    @InvocableMethod(
        label='Calculate Project Build Time'
        description='Estimates the time in hours to build a project based on pieces and builders.'
        category='Utilities'
        callout=false
    )
    public static List<ProjectBuildResponse> calculateBuildTimes(List<ProjectBuildRequest> requests) {
        List<ProjectBuildResponse> responses = new List<ProjectBuildResponse>();

        for (ProjectBuildRequest request : requests) {
            Decimal calculatedEstimatedTime = null; // Renamed variable to avoid confusion
            String errorDetailMsg = null; // Renamed variable for clarity

            // --- Input Validation ---
            if (request.numberOfPieces == null || request.numberOfPieces <= 0) {
                errorDetailMsg = 'Number of pieces must be a positive integer. Received: ' + request.numberOfPieces;
                System.debug(LoggingLevel.WARN, 'ProjectBuildTimeCalculator: ' + errorDetailMsg);
            } else if (request.numberOfBuilders == null || request.numberOfBuilders <= 0) {
                errorDetailMsg = 'Number of builders must be a positive integer. Received: ' + request.numberOfBuilders;
                System.debug(LoggingLevel.WARN, 'ProjectBuildTimeCalculator: ' + errorDetailMsg);
            } else {
                // If inputs are valid, proceed with calculation
                try {
                    calculatedEstimatedTime = performCalculation(request.numberOfPieces, request.numberOfBuilders);
                } catch (Exception e) {
                    errorDetailMsg = 'An unexpected error occurred during calculation: ' + e.getMessage();
                    System.debug(LoggingLevel.ERROR, 'ProjectBuildTimeCalculator: ' + errorDetailMsg + ' Stacktrace: ' + e.getStackTraceString());
                }
            }
            responses.add(new ProjectBuildResponse(calculatedEstimatedTime, errorDetailMsg));
        }
        return responses;
    }

    /**
     * @description Private helper method containing the core calculation logic.
     * @param numberOfPieces The total number of pieces.
     * @param numberOfBuilders The number of builders.
     * @return Decimal The estimated time in hours, rounded to two decimal places.
     */
    private static Decimal performCalculation(Integer numberOfPieces, Integer numberOfBuilders) {
        // --- 1. Calculate Collaboration Factor ---
        // This factor models how multiple builders contribute.
        Decimal collaborationFactor = 1.0; // Starts with the first builder's full effectiveness.

        if (numberOfBuilders > 1) {
            // Iterate for each *additional* builder (from the 2nd builder onwards).
            for (Integer i = 1; i < numberOfBuilders; i++) {
                Decimal additionalBuilderContribution = 1.0 - (0.2 * i);
                collaborationFactor += Math.max(0.1, additionalBuilderContribution);
            }
        }

        // --- 2. Calculate Base Time for a Solo Builder (in seconds) ---
        Decimal baseTimeSoloSeconds = (Decimal)numberOfPieces * SECONDS_PER_PIECE_SOLO;

        // --- 3. Calculate Effective Build Time (in seconds) ---
        // Ensure collaborationFactor is not zero to prevent division by zero error.
        if (collaborationFactor == 0) {
             throw new MathException('Collaboration factor cannot be zero.');
        }
        Decimal effectiveTimeSeconds = baseTimeSoloSeconds / collaborationFactor;

        // --- 4. Convert to Hours ---
        Decimal timeInHours = effectiveTimeSeconds / SECONDS_PER_HOUR;

        // --- 5. Return `time_in_hours` (rounded) ---
        return timeInHours.setScale(2, RoundingMode.HALF_UP);
    }

    /*
    // Example usage in Anonymous Apex for the InvocableMethod:
    List<ProjectBuildTimeCalculator.ProjectBuildRequest> requests = new List<ProjectBuildTimeCalculator.ProjectBuildRequest>();

    ProjectBuildTimeCalculator.ProjectBuildRequest req1 = new ProjectBuildTimeCalculator.ProjectBuildRequest();
    req1.numberOfPieces = 9876;
    req1.numberOfBuilders = 2;
    requests.add(req1);

    ProjectBuildTimeCalculator.ProjectBuildRequest req2 = new ProjectBuildTimeCalculator.ProjectBuildRequest();
    req2.numberOfPieces = 45;
    req2.numberOfBuilders = 1;
    requests.add(req2);

    ProjectBuildTimeCalculator.ProjectBuildRequest req3 = new ProjectBuildTimeCalculator.ProjectBuildRequest();
    req3.numberOfPieces = 0; // Invalid input example
    req3.numberOfBuilders = 1;
    requests.add(req3);

    List<ProjectBuildTimeCalculator.ProjectBuildResponse> responses = ProjectBuildTimeCalculator.calculateBuildTimes(requests);

    for (ProjectBuildTimeCalculator.ProjectBuildResponse res : responses) {
        if (res.errorMessage != null) {
            System.debug('Error: ' + res.errorMessage);
        } else {
            System.debug('Estimated build time: ' + res.estimatedTimeInHours + ' hours');
        }
    }
    // Expected output for req1 (9876, 2): 18.29 hours
    // Expected output for req2 (45, 1): 0.15 hours
    // Expected output for req3 (0, 1): Error: Number of pieces must be a positive integer...
    */
}